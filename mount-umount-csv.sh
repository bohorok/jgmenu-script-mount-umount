#!/usr/bin/env bash

###################    MIT License   ##########################
# 
# Copyright (c) 2023 bohorok
# https://github.com/bohorok
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

##################### SECTION CONFIG SCRIPT #######################
# Here you can add or del your directories for searching image files
image_scan_directories="$HOME/*iso/  $HOME/iso*/ $HOME/*image/ $HOME/image*/"
# Your mount point for all image files, in this directory each image is mounting in separated directory
image_mount_point="$HOME/image-mount-point/"
# Your favorite gui editor
editor="subl"
##################### END SECTION CONFIG SCRIPT ####################

function mtp_devices()
{
mtp_list_to_mount=""
mtp_list_to_umount=""
mtp_device=$(gio mount -li | awk -F= '/activation_root/ { print $2 }')
if [[ $mtp_device = mtp* ]]
   then
	mtp_mount_point=$(findmnt -l -o TARGET | grep 'gvfs')
	check_directory=$(ls $mtp_mount_point)
	if [[ -n $check_directory ]]
	 then
		mtp_list_to_umount+="$(echo ${mtp_device} | awk '{ gsub (/_/, " "); print $2,$3 }'), "
		mtp_list_to_umount+="gio mount -u \"${mtp_device}\" , none \n" 
		block_devices
	else
		 mtp_list_to_mount+="$(echo ${mtp_device} | awk '{ gsub (/_/, " "); print $2,$3 }'), "
		 mtp_list_to_mount+="gio mount \"${mtp_device}\" , none \n"
		 block_devices
	fi
else
	block_devices
fi
}

function block_devices ()
{
	block_list_to_mount=""
	block_list_to_umount=""
	detected_block_partitions=$(lsblk -l -o TYPE,PATH | awk '/part/ { print $2 }')
	for partition in $detected_block_partitions
	 do
	 	part_info_unmouting_devices=($(lsblk -l -o NAME,PATH,FSTYPE,LABEL,TYPE $partition | awk '/part/ { $1=$1 ;  print }'))
	 	part_info_mouting_devices=($(findmnt -ln -o TARGET,SOURCE,FSTYPE,LABEL $partition | awk '{ $1=$1 ; print}'))
	 	if [[ -z $part_info_mouting_devices ]]; then
	 		if [[ ${part_info_unmouting_devices[2]} != "swap" ]]; then
	 	 		block_list_to_mount+="${part_info_unmouting_devices[3]} : ${part_info_unmouting_devices[0]}, udisksctl mount -b $partition, none \n"
	 	 	else
	 	 		continue
	 		fi
	 	elif [[ -n $part_info_mouting_devices  && ${part_info_unmouting_devices[2]} != "swap" && ${part_info_mouting_devices[0]} != "/" ]]; then
	 	   	block_list_to_umount+="${part_info_mouting_devices[3]} : ${part_info_unmouting_devices[0]}, udisksctl unmount -b $partition, none \n"
	 	fi
	done
	}

function rom_devices()
{
rom_list_to_mount=""
rom_list_to_umount=""
detected_rom_devices=$(lsblk -l -o TYPE,PATH | awk '/rom/  NF>1 { $1=$1 ; print $2 }')
for cdroms in $detected_rom_devices; do
	if [[ -n $cdroms ]]; then
	 	cdrom_info_unmouting_devices=($(lsblk -l -o NAME,PATH,LABEL,TYPE $cdroms | awk '/rom/ { $1=$1 ; print }'))
		check_status_mounting=($(findmnt -ln -o TARGET,SOURCE,FSTYPE,LABEL $cdroms | awk '{ $1=$1 ; print}'))
		if [[ -z $check_status_mounting ]]; then
			rom_list_to_mount+="${cdrom_info_unmouting_devices[2]} : ${cdrom_info_unmouting_devices[0]}, udisksctl mount -b ${cdroms}, none \n"
		elif [[ -n $check_status_mounting ]]; then	
			rom_list_to_umount+="${cdrom_info_unmouting_devices[2]} : ${cdrom_info_unmouting_devices[0]}, udisksctl unmount -b ${cdroms}, none \n"
		fi
	elif [[ -z $cdroms ]]; then
		continue
	fi
done
}

function iso_files()
{
	if [[ ! -d $image_mount_point ]]; then
			mkdir -m 775 $image_mount_point
	fi
	list_to_mount_image_files=""
	list_to_umount_image_files=""
	path_to_image_files=$(find ${image_scan_directories} -maxdepth 1  -type f -iname '*.img' -o -iname '*.iso' -o -iname '*.nrg' -o -iname '*bin' -o -iname '*mdf')
		if [[ $? = 0 ]]; then
			 	for image_files  in $path_to_image_files; do
			 			name_image_file="$(echo ${image_files} | awk -F/ '{ gsub (/[.]/,"") ; print $NF }')"
						if [[ -d ${image_mount_point}${name_image_file} ]]; then
						list_to_umount_image_files+="${image_mount_point}${name_image_file}, fusermount -u ${image_mount_point}${name_image_file}, none \n"
						else
						list_to_mount_image_files+="${image_files}, fuseiso -p ${image_files} ${image_mount_point}${name_image_file}, none \n"
						fi
				done
		fi	
   # Another iso mount commands
	# mount -o loop disk1.iso /mnt/disk
	# sudo mount -t iso9660 -o loop file.iso / media / iso
}

function generate_csv()
{
printf "^sep(: : : :Mount / Umount : : : :)
Mount, ^checkout(mount), none
Umount, ^checkout(umount), none
^sep(: : : : : : : : : Config : : : : : : : :)
edit fstab, $TERMINAL -e bash -c 'sudo ${editor} -n /etc/fstab', none
^sep(: : : : : : : : : : : : : : : : : : : : : : : :)
^tag(mount)
^sep(: : : : : Mount Android-mtp devices : : : : : :)
${mtp_list_to_mount}
^sep(: : : : : : : Mount block partitions : : : : : : : )
${block_list_to_mount}
^sep(: : : : : : : : : Mount CD/DVD/BD : : : : : : : : )
${rom_list_to_mount}
^sep(: : : : : : : : : : : Mount ISO files : : : : : : : : : : )
${list_to_mount_image_files}
^tag(umount)
^sep(: : : : Unmount Android-mtp  devices : : : :)
${mtp_list_to_umount}
^sep( : : : : : : Unmount block partitions : : : : : : )
${block_list_to_umount}
^sep(: : : : : : : : Unmount CD/DVD/BD : : : : : : : )
${rom_list_to_umount}
^sep(: : : : : : : : : : Unmount ISO files : : : : : : : : : )
${list_to_umount_image_files}
"
}
mtp_devices
rom_devices
iso_files
generate_csv

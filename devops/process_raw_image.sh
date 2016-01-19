#!/bin/bash

if ! id | grep -q root; then
	echo "must be run as root"
	exit 1
fi

temp="/tmp/image_creator"
eMMC=/dev/md2
sdcard="."
current_folder=$(pwd)
output_dir=$current_folder
BASEDIR=$(dirname $0)

echo "current dir $current_folder"

if [ -z $1 ]
then
	sdcard=$current_folder

	if [ -e ${current_folder}/eMMC_part1.img ]
	then
		sdcard=$current_folder
	elif [ -e ${BASEDIR}/eMMC_part1.img ]
        then
                sdcard=$BASEDIR
	fi

	echo "No sdcard path given.. assuming same directory: $sdcard"
else
	if [ -e $1 ]
	then
		echo "Path found: $1"
		sdcard=$1
	else
		echo "Path not found: $1"
		exit 1
	fi
fi

if [ -z $2 ]
then
	echo "No output path given.. assuming current directory: $current_folder"
	output_dir=$current_folder
else
	output_dir=$2
	if [ -e $2 ]
	then
		echo "Path found: $2"
	else
		mkdir -p $2
		if [ -e $2 ]
		then
			echo "Path created: $2"
			BASEDIR=$(dirname $0)
		else
			echo "Cann't create path: $2"
			exit 1
		fi
	fi
fi

if [ ! -e ${output_dir}/p1 ]
then
	mkdir -p ${output_dir}/p1
fi

if [ ! -e ${output_dir}/p2/scripts/ ]
then
	mkdir -p ${output_dir}/p2/scripts/
fi

echo copying card contents from $BASEDIR/factory_settings_sdcard/ to $output_dir/p1
cp -r $BASEDIR/factory_settings_sdcard/* $output_dir/p1
cp $BASEDIR/factory_settings_sdcard/scripts/* $output_dir/p2/scripts/

image_filename_upgrade="${temp}/eMMC.img"
image_filename_upgrade1="$sdcard/eMMC_part1.img"
image_filename_upgrade2="$sdcard/eMMC_part2.img"
upgrade_scripts="scripts"

echo "Packing eMMC image.."

if [ -e  ${temp} ]
then
	echo "$temp: exists!"
#	rm -r "$temp/">/dev/null
else
	mkdir -p ${temp}/$upgrade_scripts
fi

cp $BASEDIR/factory_settings_sdcard/scripts/* $temp/$upgrade_scripts

if [ ! -e $image_filename_upgrade1 ]
then
	echo "First image part not found: $image_filename_upgrade1"
	exit 1
fi

if [ ! -e $image_filename_upgrade2 ]
then
	echo "Second image part not found: $image_filename_upgrade2"
	exit 1
fi

unmount_all () {
	if [ -e /dev/md2 ]
	then
		sync
		sleep 2
		fuser -m /dev/md2* --all -u -v -k
		mdadm --stop /dev/md2
	fi
	losetup -d /dev/loop2
}

echo "Processing eMMC image: $eMMC"
cat $image_filename_upgrade1 $image_filename_upgrade2 > $image_filename_upgrade
if [ $? -gt 0 ]
then
	echo "Error concatinating image parts!"
	unmount_all
	exit 1
fi

echo Extracting partitions...
losetup /dev/loop2 $image_filename_upgrade
if [ $? -gt 0 ]
then
	echo "Error creating a block device for $image_filename_upgrade!"
	unmount_all
	exit 1
fi

mdadm --build --level=0 --force --raid-devices=1 /dev/md2 /dev/loop2
if [ $? -gt 0 ]
then
	echo "Error mapping partitions for $image_filename_upgrade!"
	unmount_all
	exit 1
fi

image_filename_folder="${temp}"

image_filename_prfx="upgrade"
image_filename_rootfs="$image_filename_prfx-rootfs.img.gz"
image_filename_data="$image_filename_prfx-data.img.gz"
image_filename_boot="$image_filename_prfx-boot.img.gz"
image_filename_pt="$image_filename_prfx-pt.img.gz"

checksums_filename="$image_filename_prfx-checksums.txt"

image_filename_upgrade_temp="${temp}/temp.tar"
image_filename_upgrade1="${output_dir}/p2/upgrade.img.tar"

echo "SDCard: $sdcard"
cd ${temp}

image_filename_upgrade2="${output_dir}/p1/factory_settings.img.tar"

echo "Packing eMMC image.."

echo "Temp folder: $image_filename_folder"
ls $image_filename_folder

#if [ -e  $image_filename_upgrade_tar_temp ]
#then
#	rm $image_filename_upgrade_tar_temp
#fi

if [ -e $image_filename_upgrade_temp ]
then
	rm $image_filename_upgrade_temp
fi

if [ -e $image_filename_upgrade1 ]
then
	rm $image_filename_upgrade1
fi

if [ -e $image_filename_upgrade2 ]
then
	rm $image_filename_upgrade2
fi

echo "Copying eMMC partitions at $eMMC"
sync
echo "Packing partition table to: $image_filename_pt"
dd  if=${eMMC} bs=16M count=1 | gzip -c > $image_filename_pt

echo "Chaibio Checksum File">$checksums_filename
md5sum $image_filename_pt>>$checksums_filename
sleep 2
sync

if [ ! -e /tmp/emmc ]
then
	mkdir -p /tmp/emmc
fi

rootfs_partition=${eMMC}p2
data_partition=${eMMC}p3

if [ ! -e $rootfs_partition ]
then
        echo "Root file system partition not found: $rootfs_partition"
	exit 1
fi

if [ ! -e $data_partition ]
then
        echo "Data file system partition not found: $rootfs_partition"
	exit 1
fi

mount $rootfs_partition /tmp/emmc -t ext4
retval=$?

if [ $retval -ne 0 ]; then
    echo "Error mounting rootfs partition! Error($retval)"
else
	echo "Zeroing rootfs partition"
	dd if=/dev/zero of=/tmp/emmc/big_zero_file1.bin bs=16M > /dev/null
	result=$?
	sync &
	sleep 5

	sync
	echo "Removing zeros file"
	rm /tmp/emmc/big_zero_file*
	sync &
	sleep 10
	sync
	umount /tmp/emmc > /dev/null || true
fi

echo "Packing binaries partition to: $image_filename_rootfs"
dd  if=${eMMC}p2 bs=16M | gzip -c > $image_filename_rootfs
md5sum $image_filename_rootfs>>$checksums_filename

sleep 5
sync

echo "Packing boot partition to: $image_filename_boot"
dd  if=${eMMC}p1 bs=16M | gzip -c > $image_filename_boot
md5sum $image_filename_boot>>$checksums_filename

#create scripts folder inside the tar
if [ ! -e $upgrade_scripts ]
then
	mkdir -p $upgrade_scripts/
fi

#cp $BASEDIR/factory_settings_sdcard/scripts/* $upgrade_scripts/
#echo "cp $BASEDIR/factory_settings_sdcard/scripts/* $upgrade_scripts/"
#echo "${pwd}"
#exit


echo "Data partition: $data_partition"
mount $data_partition /tmp/emmc -t ext4
retval=$?

	if [ $retval -ne 0 ]; then
	    echo "Error mounting data partition! Error($retval)"
	else
		echo "Zeroing data partition"
		dd if=/dev/zero of=/tmp/emmc/big_zero_file.bin > /dev/null
		sync &
		sleep 5
		sync

		echo "Removing zeros file"
		rm /tmp/emmc/big_zero_file.bin
		sync &
		sleep 10
		sync

		umount /tmp/emmc > /dev/null || true
	fi

	echo "Packing data partition to: $image_filename_data"
	dd  if=${eMMC}p3 bs=16M | gzip -c > $image_filename_data
	md5sum $image_filename_data>>$checksums_filename

	#tarring
#	echo "compressing all images to $image_filename_upgrade_tar_temp"
	tar -cvf $image_filename_upgrade_temp $image_filename_pt $image_filename_boot $image_filename_data $image_filename_rootfs $checksums_filename


	if [ -e $image_filename_data ]
	then
		rm $image_filename_data
	else
       		echo "Data image not found: $image_filename_data"
	fi

	echo "Finalizing: $image_filename_upgrade2"
	mv $image_filename_upgrade_temp $image_filename_upgrade2

#echo "mv $image_filename_upgrade_temp $image_filename_upgrade2"
#exit 0

if [ -e $image_filename_upgrade_temp ]
then
	rm $image_filename_upgrade_temp
fi

tar -cvf $image_filename_upgrade_temp $image_filename_pt $image_filename_boot $image_filename_rootfs $checksums_filename $upgrade_scripts

echo "Remove packed files"
if [ -e $image_filename_boot ]
then
	rm $image_filename_boot
else
       	echo "Boot image not found: $image_filename_boot"
fi

if [ -e $image_filename_rootfs ]
then
	rm $image_filename_rootfs
else
        echo "Rootfs image not found: $image_filename_rootfs"
fi

if [ -e $image_filename_pt ]
then
	rm $image_filename_pt
fi

cd $current_folder

echo "Finalizing: $image_filename_upgrade1"
mv $image_filename_upgrade_temp $image_filename_upgrade1

if [ -e ${sdcard}/pack_resume_autorun.flag ]
then
	rm ${sdcard}/pack_resume_autorun.flag>/dev/null || true
fi

sync
unmount_all
ls -ahl $output_dir/p1 $output_dir/p2

echo "Finished.. byebye!"

if [ -e $image_filename_upgrade1 ]
then
	exit 0
fi

exit 1

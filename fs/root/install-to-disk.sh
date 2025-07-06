#!/usr/bin/env bash

set -e


get_default_image() {
    if [[ -f dist/debian.img ]]; then
        echo "dist/debian.img"
    else
        CURRENT_PARTITION=$(findmnt / -o source -n)
        CURRENT_DISK_NAME=$(lsblk -no pkname $CURRENT_PARTITION)
        
        echo "/dev/$CURRENT_DISK_NAME"
    fi
}

if [[ -z $IMAGE_PATH ]]; then 
    DEFAULT_IMAGE_PATH=`get_default_image`
    read -p "Path to image ($DEFAULT_IMAGE_PATH): " IMAGE_PATH
    if [[ -z $IMAGE_PATH ]]; then
        IMAGE_PATH=$DEFAULT_IMAGE_PATH
        echo "Using image: $IMAGE_PATH"
    fi
fi

echo
echo "*******************"
echo


disks=()
sizes=()
names=()
while IFS= read -r -d $'\0' device; do
    size=$(lsblk -bno SIZE $device | head -1)
    device=${device/\/dev\//}
    disks+=($device)
    names+=(`cat "/sys/class/block/$device/device/model"`)
    sizes+=(`numfmt --to=iec $size`)
done < <(find "/dev/" -regex '/dev/sd[a-z]\|/dev/vd[a-z]\|/dev/hd[a-z]' -print0)

found=false

while [[ $found == "false" ]]; do
    for i in `seq 0 $((${#disks[@]}-1))`; do
        echo -e "${disks[$i]}\t${names[$i]}\t${sizes[$i]}"
    done

    echo 
    read -p "Which device do you want to install to? " selected_disk
    
    for disk in "${disks[@]}"; do
        if [[ "$disk" == "$selected_disk" ]]; then
            found=true
            break
        fi
    done
done

selected_disk=/dev/$selected_disk

read -p "Are you sure you want to install and wipe all of data on $selected_disk? (Y/n) " confirm
if [[ $confirm != "Y" ]]; then
    echo "Cancelled"
    exit 1;
fi


echo 
fdisk -l $selected_disk
echo 

echo ">" dd if=$IMAGE_PATH of=$selected_disk bs=128M status=progress oflag=direct
dd if=$IMAGE_PATH of=$selected_disk bs=128M status=progress oflag=direct

sync 

partprobe $selected_disk || true

echo 
fdisk -l $selected_disk
echo 

export PARTITION=`lsblk -no PATH $selected_disk | sed -n '2 p'`

echo ">" growpart $selected_disk 1
growpart $selected_disk 1


fdisk -l $selected_disk

umount $PARTITION || true

echo ">" e2fsck -fy $PARTITION
e2fsck -fy $PARTITION

echo ">" resize2fs $PARTITION
resize2fs $PARTITION

sync
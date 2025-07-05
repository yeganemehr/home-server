#!/bin/bash

set -e

VM_DISK_SIZE_MB=2048

echo "Building docker image..."
IMAGE_ID=$(docker build -q .)
echo "Image ID: $IMAGE_ID"

echo "Running container..."
CONTAINER_ID=$(docker run -d $IMAGE_ID)
echo "container ID: $CONTAINER_ID"

echo "Building disk image..."
rm -fr dist wd
mkdir dist wd
fallocate --length "${VM_DISK_SIZE_MB}M" dist/debian.img
echo "type=83,bootable" | sfdisk dist/debian.img
echo "Building disk image: done"


echo "Partitioning..."
losetup -D
LOOPDEVICE=$(losetup -f --partscan --show dist/debian.img)
PRIMARY_PART="${LOOPDEVICE}p1"
mkfs.ext4 $PRIMARY_PART
export PRIMARY_PART_UUID=$(blkid -o value -s UUID $PRIMARY_PART)
echo "Partitioning: $PRIMARY_PART_UUID"

echo "Export docker image..."
mount -t auto $PRIMARY_PART wd
docker export $CONTAINER_ID | tar -C wd --numeric-owner -xf -
docker rm $CONTAINER_ID
envsubst < wd/boot/syslinux.cfg | sponge wd/boot/syslinux.cfg
rm -f wd/.dockerenv
rm -f wd/etc/resolv.conf
echo "Export docker image: done"

echo "Make image bootable..."
extlinux --install wd/boot/

umount wd
rm -fr wd
losetup -d $LOOPDEVICE

dd if=/usr/lib/syslinux/mbr/mbr.bin of=dist/debian.img bs=440 count=1 conv=notrunc
echo "Done"

# qemu-img convert -c dist/debian.img -O qcow2 dist/debian.qcow2

# rm -f dist/debian.img 
#!/usr/bin/env bash

set -e

export IMAGE_PATH="dist/debian.img"

if [[ -f $IMAGE_PATH ]]; then

    echo "Using image: $IMAGE_PATH"
else
    echo "Cannot find $IMAGE_PATH file, you probably want to run ./build.sh first!"
    exit 1
fi

source fs/root/install-to-disk.sh

echo "Copy raw image to USB..."
mkdir -p wd
mount $PARTITION wd
mkdir -p wd/root/$(dirname $IMAGE_PATH)
cp $IMAGE_PATH wd/root/$IMAGE_PATH
sync
umount wd

echo "Copy raw image to USB: Done"
#!/bin/bash

echo 'Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/90force-ipv4
sudo apt upgrade -y && sudo apt update;

# creating disk partion and filesyastem
if [[ "${FILE_SYSTEM}" == "xfs" ]]; then
  sudo apt-get install xfsprogs
  sudo modprobe -v xfs
  FSCK=0
else
  FSCK=1
fi

if [[ "${DISK_SIZE_SECOND}" != "" ]]; then
  sudo apt-get install -y lvm2
  sudo pvcreate /dev/sdb
  sudo vgcreate second /dev/sdb
  sudo lvcreate -l 100%VG -n sdb1 second
  sudo "mkfs.${FILE_SYSTEM}" /dev/second/sdb1
  sudo mount /dev/second/sdb1 "${MOUNTING_POINT}"
  echo "/dev/second/sdb1 ${MOUNTING_POINT} ${FILE_SYSTEM} defaults 0 ${FSCK}" >> /etc/fstab
fi

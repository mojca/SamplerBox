#!/bin/bash -v
# The script takes a standard RaspiOS Lite image, installs SamplerBox on it, and creates a ready-to-use image.
# Notes: 
# * this script works on Pi4 but not on Pi2 - tested 2022-08-09
# * the process is quite long, 1 hr 40 min on a Pi4 - for this reason, I usually start it from screen (screen -S maker, sudo ./maker.sh, CTRL A D to detach)
#
# SamplerBox (https://www.samplerbox.org)
# License: Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International (CC BY-NC-SA 4.0) (https://creativecommons.org/licenses/by-nc-sa/4.0/)

set -e  # exit immediately if a command exits with a non-zero status
apt install -y kpartx parted zip
[ ! -f "2022-09-22-raspios-bullseye-arm64-lite.img.xz" ] && wget https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2022-09-26/2022-09-22-raspios-bullseye-arm64-lite.img.xz
[ ! -f "2022-09-22-raspios-bullseye-arm64-lite.img" ] && unxz --keep 2022-09-22-raspios-bullseye-arm64-lite.img.xz
cp 2022-09-22-raspios-bullseye-arm64-lite.img sb.img
truncate -s 2500M sb.img      # M=1024*1024
kpartx -av sb.img
parted -m /dev/loop0 resizepart 2 2499MiB  # MiB=1024*1024
kpartx -uv /dev/loop0
resize2fs /dev/mapper/loop0p2     # enlarge partition  # e2fsck -f /dev/mapper/loop0p2
mkdir -v -p sdcard
mount -v -t ext4 -o sync /dev/mapper/loop0p2 sdcard
mount -v -t vfat -o sync /dev/mapper/loop0p1 sdcard/boot
echo root:root | chroot sdcard chpasswd
chroot sdcard apt update
chroot sdcard apt -y install git python3-pip python3-smbus python3-numpy libportaudio2 raspberrypi-kernel ntpdate libasound2-dev libjack-dev
chroot sdcard pip3 install cython python-rtmidi cffi sounddevice pyserial
chroot sdcard sh -c "cd /root ; git clone https://github.com/josephernest/SamplerBox.git ; cd SamplerBox ; git remote add mojca https://github.com/mojca/SamplerBox.git ; git checkout midiatonerca ; python3 setup.py build_ext --inplace"
cp -R root/* sdcard
chroot sdcard chmod +x /root/usb-mount.sh
chroot sdcard systemctl enable /etc/systemd/system/samplerbox.service
chroot sdcard systemctl disable systemd-timesyncd systemd-rfkill hciuart raspi-config avahi-daemon resize2fs_once rpi-eeprom-update dphys-swapfile
chroot sdcard systemctl disable regenerate_ssh_host_keys sshswitch
chroot sdcard ssh-keygen -A -v
chroot sdcard systemctl enable ssh
sed -i 's/ENV{pvolume}:="-20dB"/ENV{pvolume}:="-10dB"/' sdcard/usr/share/alsa/init/default
echo "PermitRootLogin yes" >> sdcard/etc/ssh/sshd_config
echo "alias rw=\"mount -o remount,rw /\"" >> sdcard/root/.bashrc
sync
umount -v sdcard/boot
umount -v sdcard
kpartx -dv sb.img
sync
xz -zkv sb.img
exit 0

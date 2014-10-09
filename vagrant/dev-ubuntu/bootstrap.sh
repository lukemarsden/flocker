#!/bin/sh

# This script builds the base flocker-dev box for Ubuntu.

set -e

export DEBIAN_FRONTEND=noninteractive

apt-get update

echo "Installing ZFS from latest git HEAD"
apt-get -y install build-essential gawk alien fakeroot linux-headers-$(uname -r) zlib1g-dev uuid-dev libblkid-dev libselinux-dev parted lsscsi dh-autoreconf linux-crashdump git

apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys E871F18B51E0147C77796AC81196BA81F6B0FC61
echo deb http://ppa.launchpad.net/zfs-native/stable/ubuntu trusty main  > /etc/apt/sources.list.d/zfs.list

apt-get update
apt-get -y install ubuntu-zfs

mkdir -p /opt/flocker-pool
truncate --size 1G /opt/flocker-pool/pool-vdev
zpool create flocker /opt/flocker-pool/pool-vdev

# Install pip and some other deps
apt-get install -y python-pip python-dev libxml2-dev libxslt1-dev libssl-dev screen telnet strace exuberant-ctags apt-transport-https iotop htop util-linux

# Clone flocker into /opt
cd /opt
git clone -b ubuntu-vagrant https://github.com/lukemarsden/flocker

# Use pip to upgrade itself and install all requirements
cd flocker
pip install --upgrade pip
easy_install -U distribute # An error message told me to do this :(
/usr/local/bin/pip install -r requirements.txt
python setup.py install

apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 36A1D7869245C8950F966E92D8576A8BA88D21E9

echo deb https://get.docker.io/ubuntu docker main > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get -y install lxc-docker

sed -i'backup' s/USE_KDUMP=0/USE_KDUMP=1/g /etc/default/kdump-tools


#! /usr/bin/env bash
set -e

sed -i 's/deb.debian.org/httpredir.debian.org/g' /etc/apt/sources.list

apt-get update -qq
apt-get upgrade -yqq

apt-get install wget unzip autoconf pkg-config build-essential libtool python3-pip ninja-build clang llvm-dev git -yqq
pip3 install --require-hashes -r /requirements.txt
rm /requirements.txt
wget -O ndk.zip https://dl.google.com/android/repository/android-ndk-r14b-linux-x86_64.zip
echo "0ecc2017802924cf81fffc0f51d342e3e69de6343da892ac9fa1cd79bc106024 ndk.zip" | sha256sum --check
unzip ndk.zip
rm ndk.zip
apt-get remove --purge unzip -yqq
apt-get -yqq autoremove
apt-get -yqq clean
rm -rf /var/lib/apt/lists/* /var/cache/* /tmp/* /usr/share/locale/* /usr/share/man /usr/share/doc /lib/xtables/libip6* /root/.cache

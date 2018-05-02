#! /usr/bin/env bash
set -e

dnf update -yq
dnf install -yq @development-tools wget autoconf pkg-config libtool ninja-build clang which python2
pip3 install --require-hashes -r /requirements.txt

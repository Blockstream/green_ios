#!/usr/bin/env bash
set -e

export NUM_JOBS=4
if [ -f /proc/cpuinfo ]; then
    export NUM_JOBS=$(cat /proc/cpuinfo | grep ^processor | wc -l)
fi

./tools/deps.sh
NINJA=$(which ninja-build) || true
if [ ! -x "$NINJA" ] ; then
    NINJA=$(which ninja)
fi

export CFLAGS="$CFLAGS -O3" # Must  add optimisation flags for secp
export CPPFLAGS="$CFLAGS"

if [ \( $# -eq 0 \) -o \( "$1" = "--gcc" \) ]; then
    export CXX=g++
    export CC=gcc

    if [ ! -d "build-gcc" ]; then
        meson build-gcc
    fi

    cd build-gcc
    $NINJA -j$NUM_JOBS
    cd ..
fi

if [ \( $# -eq 0 \) -o \( "$1" = "--clang" \) ]; then
    export CXX=clang++
    export CC=clang
    if [ ! -d "build-clang" ]; then
        meson build-clang
    fi

    cd build-clang
    $NINJA -j$NUM_JOBS
fi

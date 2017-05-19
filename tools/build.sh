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
export PKG_CONFIG_PATH_BASE=$PKG_CONFIG_PATH
export PATH_BASE=$PATH

if [ \( "$(uname)" != "Darwin" \) -a \( $# -eq 0 \) -o \( "$1" = "--gcc" \) ]; then
    export CXX=g++
    export CC=gcc
    export BOOST_ROOT="$PWD/build-gcc/thirdparty/boost_1_64_0/build"
    export OPENSSL_PKG_CONFIG_PATH="$PWD/build-gcc/thirdparty/openssl-1.0.2k/build/lib/pkgconfig"
    export WALLY_PKG_CONFIG_PATH="$PWD/build-gcc/thirdparty/libwally-core/build/lib/pkgconfig"
    export PKG_CONFIG_PATH=$OPENSSL_PKG_CONFIG_PATH:$WALLY_PKG_CONFIG_PATH:$PKG_CONFIG_PATH_BASE

    rm -fr src/wally/src/.libs
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
    export BOOST_ROOT="$PWD/build-clang/thirdparty/boost_1_64_0/build"
    export OPENSSL_PKG_CONFIG_PATH="$PWD/build-clang/thirdparty/openssl-1.0.2k/build/lib/pkgconfig"
    export WALLY_PKG_CONFIG_PATH="$PWD/build-clang/thirdparty/libwally-core/build/lib/pkgconfig"
    export PKG_CONFIG_PATH=$OPENSSL_PKG_CONFIG_PATH:$WALLY_PKG_CONFIG_PATH:$PKG_CONFIG_PATH_BASE

    rm -fr src/wally/src/.libs
    if [ ! -d "build-clang" ]; then
        meson build-clang
    fi

    cd build-clang
    $NINJA -j$NUM_JOBS
    cd ..
fi

if [ \( -d "$ANDROID_NDK" \) -a \( $# -eq 0 \) -o \( "$1" = "--ndk-multiarch" \) ]; then

    function build() {
        case $1 in
            armeabi)
                arch=arm
                #export CFLAGS="-march=armv5te -mtune=xscale -msoft-float -mthumb"
                ;;
            armeabi-v7a)
                arch=arm
                #export CFLAGS="-march=armv7-a -mfloat-abi=softfp -mfpu=neon -mthumb"
                #export LDFLAGS="-Wl,--fix-cortex-a8"
                ;;
            arm64-v8a)
                arch=arm64
                #export CFLAGS="-flax-vector-conversions"
                ;;
            mips)
                arch=mips
                # FIXME: Only needed until mips32r2 is not the default in clang
                #export CFLAGS="-mips32"
                #export LDLAGS="-mips32"
                ;;
            *)
                arch=$1
        esac

        #export CFLAGS="$CFLAGS -O3" # Must  add optimisation flags for secp
        #export CPPFLAGS="$CFLAGS"

        if [[ $arch == *"64"* ]]; then
            export ANDROID_VERSION="21"
        else
            export ANDROID_VERSION="14"
        fi

        export BOOST_ROOT="$PWD/build-clang-$1/thirdparty/boost_1_64_0/build"
        export PATH=$PWD/build-clang-$1/toolchain/bin:$PATH_BASE
        export OPENSSL_PKG_CONFIG_PATH="$PWD/build-clang-$1/thirdparty/openssl-1.0.2k/build/lib/pkgconfig"
        export WALLY_PKG_CONFIG_PATH="$PWD/build-clang-$1/thirdparty/libwally-core/build/lib/pkgconfig"
        export PKG_CONFIG_PATH=$OPENSSL_PKG_CONFIG_PATH:$WALLY_PKG_CONFIG_PATH:$PKG_CONFIG_PATH_BASE

        export AR="$PWD/build-clang-$1/toolchain/bin/arm-linux-androideabi-ar"
        export RANLIB="$PWD/build-clang-$1/toolchain/bin/arm-linux-androideabi-ranlib"
        rm -fr src/wally/src/.libs
        if [ ! -d "build-clang-$1" ]; then
            $ANDROID_NDK/build/tools/make_standalone_toolchain.py --arch $arch --api $ANDROID_VERSION --install-dir="$PWD/build-clang-$1/toolchain" &>/dev/null
            ./tools/make_txt.sh $PWD/build-clang-$1 > $PWD/build-clang-$1/$1_ndk.txt
            meson build-clang-$1 --cross-file $PWD/build-clang-$1/$1_ndk.txt
        fi
        cd build-clang-$1
        $NINJA -j$NUM_JOBS
    }

    #export CXX=clang++
    #export CC=clang
    #all_archs="armeabi armeabi-v7a arm64-v8a mips mips64 x86 x86_64"
    all_archs="armeabi-v7a"

    for a in $all_archs; do
        build $a
    done
fi

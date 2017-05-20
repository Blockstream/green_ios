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

if [ \( -d "$ANDROID_NDK" \) -a \( $# -eq 0 \) -o \( "$1" = "--ndk" \) ]; then

    if [ -z "$ANDROID_NDK" ]; then
        if [ $(which ndk-build) ]; then
            export ANDROID_NDK=$(dirname `which ndk-build 2>/dev/null`)
        fi
    fi

    echo ${ANDROID_NDK:?}
    function build() {
        echo $1
        bld_root="$PWD/build-clang-$1"
        case $1 in
            armeabi)
                export SDK_ARCH=arm
                export SDK_CPU=armv7
                #export SDK_PLATFORM=arm-linux-androideabi
                export SDK_CFLAGS="-march=armv5te -mtune=xscale -msoft-float -mthumb"
                ;;
            armeabi-v7a)
                export SDK_ARCH=arm
                export SDK_CPU=armv7
                #export SDK_PLATFORM=arm-linux-androideabi
                export SDK_CFLAGS="-march=armv7-a -mfloat-abi=softfp -mfpu=neon -mthumb"
                export SDK_LDFLAGS="-Wl,--fix-cortex-a8"
                ;;
            arm64-v8a)
                export SDK_ARCH=arm64
                export SDK_CFLAGS="-flax-vector-conversions"
                #export SDK_PLATFORM=i686-linux-android
                export SDK_CPU=i686
                ;;
            mips)
                export SDK_ARCH=mips
                # FIXME: Only needed until mips32r2 is not the default in clang
                export SDK_CFLAGS="-mips32"
                export SDK_LDLAGS="-mips32"
                ;;
            *)
                export SDK_ARCH=$1
                #export SDK_PLATFORM=i686-linux-android
                export SDK_CPU=i686
        esac

        export SDK_CFLAGS="$SDK_CFLAGS -O3" # Must  add optimisation flags for secp
        export SDK_CPPFLAGS="$SDK_CFLAGS"

        if [[ $SDK_ARCH == *"64"* ]]; then
            export ANDROID_VERSION="21"
        else
            export ANDROID_VERSION="14"
        fi
        bld_third_party="$bld_root/thirdparty"
        export BOOST_ROOT="$bld_third_party/boost_1_64_0/build"
        export PATH=$bld_root/toolchain/bin:$PATH_BASE
        export OPENSSL_PKG_CONFIG_PATH="$bld_third_party/openssl-1.0.2k/build/lib/pkgconfig"
        export WALLY_PKG_CONFIG_PATH="$bld_third_party/libwally-core/build/lib/pkgconfig"
        export PKG_CONFIG_PATH=$OPENSSL_PKG_CONFIG_PATH:$WALLY_PKG_CONFIG_PATH:$PKG_CONFIG_PATH_BASE


        rm -fr src/wally/src/.libs
        if [ ! -d "$bld_root" ]; then
            $ANDROID_NDK/build/tools/make_standalone_toolchain.py --arch $SDK_ARCH --api $ANDROID_VERSION --install-dir="$bld_root/toolchain" &>/dev/null
            export SDK_PLATFORM=$(basename $(find $bld_root/toolchain/ -maxdepth 1 -type d -name "*linux-android*"))
            export AR="$bld_root/toolchain/bin/$SDK_PLATFORM-ar"
            export RANLIB="$bld_root/toolchain/bin/$SDK_PLATFORM-ranlib"
            ./tools/make_txt.sh $bld_root > $bld_root/$1_ndk.txt
            meson build-clang-$1 --cross-file $bld_root/$1_ndk.txt
        fi
        cd build-clang-$1
        $NINJA -j$NUM_JOBS -v
        cd ..
    }

    #export CXX=clang++
    #export CC=clang
    #all_archs="armeabi armeabi-v7a arm64-v8a mips mips64 x86 x86_64"
    #all_archs="armeabi-v7a"
    #all_archs="x86"
    #all_archs="mips64"
    all_archs="armeabi-v7a arm64-v8a x86_64 mips64"
    for a in $all_archs; do
        build $a
    done
fi

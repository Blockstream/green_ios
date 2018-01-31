#!/usr/bin/env bash
set -e
export NUM_JOBS=4
if [ -f /proc/cpuinfo ]; then
    export NUM_JOBS=$(cat /proc/cpuinfo | grep ^processor | wc -l)
fi

NINJA=$(which ninja-build) || true
if [ ! -x "$NINJA" ] ; then
    NINJA=$(which ninja)
fi

LIBTYPE="${@: -1}"
if test "x${LIBTYPE}" != "xshared" && test "x${LIBTYPE}" != "xstatic" ; then
    LIBTYPE=shared
fi

ANALYZE="${@: -1}"
if test "x${ANALYZE}" != "x--analyze" ; then
    ANALYZE=""
fi

export CFLAGS="$CFLAGS"
export CPPFLAGS="$CFLAGS"
export PKG_CONFIG_PATH_BASE=$PKG_CONFIG_PATH
export PATH_BASE=$PATH

function build() {
    ./tools/deps.sh $PWD/build-$1
    export CXX=$2
    export CCC_CXX=$2
    export CC=$1
    export CCC_CC=$1
    export CC=$1
    export BOOST_ROOT="$PWD/build-$1/boost_1_64_0/build"
    export OPENSSL_PKG_CONFIG_PATH="$PWD/build-$1/openssl-1.0.2m/build/lib/pkgconfig"
    export WALLY_PKG_CONFIG_PATH="$PWD/build-$1/libwally-core/build/lib/pkgconfig"
    export PKG_CONFIG_PATH=$OPENSSL_PKG_CONFIG_PATH:$WALLY_PKG_CONFIG_PATH:$PKG_CONFIG_PATH_BASE

    SCAN_BUILD=""
    if [ "x${ANALYZE}" = "x--analyze" ] ; then
        SCAN_BUILD="scan-build --use-cc=$1 --use-c++=$2"
    fi

    if [ ! -f "build-$1/build.ninja" ]; then
        rm -rf build-$1/meson-private
        $SCAN_BUILD meson build-$1 --default-library=${LIBTYPE} --buildtype=debug
    fi

    cd build-$1
    $NINJA -j$NUM_JOBS
    cd ..
}

function set_cross_build_env() {
    bld_root="$PWD/build-clang-$1-$2"
    ./tools/deps.sh $bld_root
    export BOOST_ROOT="$bld_root/boost_1_64_0/build"
    export OPENSSL_PKG_CONFIG_PATH="$bld_root/openssl-1.0.2m/build/lib/pkgconfig"
    export WALLY_PKG_CONFIG_PATH="$bld_root/libwally-core/build/lib/pkgconfig"
    export PKG_CONFIG_PATH=$OPENSSL_PKG_CONFIG_PATH:$WALLY_PKG_CONFIG_PATH:$PKG_CONFIG_PATH_BASE
    export HOST_ARCH=$2
    case $2 in
        armeabi)
            export SDK_ARCH=arm
            export SDK_CPU=armv7
            export SDK_CFLAGS="-march=armv5te -mtune=xscale -msoft-float -mthumb"
            ;;
        armeabi-v7a)
            export SDK_ARCH=arm
            export SDK_CPU=armv7
            export SDK_CFLAGS="-march=armv7-a -mfloat-abi=softfp -mfpu=neon -mthumb"
            export SDK_LDFLAGS="-Wl,--fix-cortex-a8"
            ;;
        arm64-v8a)
            export SDK_ARCH=arm64
            export SDK_CFLAGS="-march=armv8-a -flax-vector-conversions"
            ;;
        mips)
            export SDK_ARCH=mips
            # FIXME: Only needed until mips32r2 is not the default in clang
            export SDK_CFLAGS="-mips32"
            export SDK_LDLAGS="-mips32"
            ;;
        mips64)
            export SDK_ARCH=mips64
            export SDK_CFLAGS="-mxgot"
            export SDK_LDLAGS="-mxgot"
            ;;
        iphone)
            export SDK_ARCH=arm
            export SDK_CFLAGS="-miphoneos-version-min=9"
            ;;
        iphonesim)
            export SDK_ARCH=x86
            export SDK_CFLAGS="-miphoneos-version-min=9"
            ;;
        *)
            export SDK_ARCH=$2
            export SDK_CPU=i686
            ;;
    esac
}

if [ \( "$(uname)" != "Darwin" \) -a \( $# -eq 0 \) -o \( "$1" = "--gcc" \) ]; then
    build gcc g++
fi


if [ \( $# -eq 0 \) -o \( "$1" = "--clang" \) ]; then
    build clang clang++
fi

if [ \( -d "$ANDROID_NDK" \) -a \( $# -eq 0 \) -o \( "$1" = "--ndk" \) ]; then

    if [ -z "$ANDROID_NDK" ]; then
        if [ $(which ndk-build) ]; then
            export ANDROID_NDK=$(dirname `which ndk-build 2>/dev/null`)
        fi
    fi

    echo ${ANDROID_NDK:?}
    function build() {
        bld_root="$PWD/build-clang-$1-$2"

        export SDK_CFLAGS="$SDK_CFLAGS -fPIC"
        export SDK_CPPFLAGS="$SDK_CFLAGS"

        if [[ $SDK_ARCH == *"64"* ]]; then
            export ANDROID_VERSION="21"
        else
            export ANDROID_VERSION="14"
        fi
        export PATH=$bld_root/toolchain/bin:$PATH_BASE

        if [ ! -f "build-clang-$1-$2/build.ninja" ]; then
            rm -rf build-clang-$1-$2/meson-private
            if [ ! -f "build-clang-$1-$2/toolchain" ]; then
                $ANDROID_NDK/build/tools/make_standalone_toolchain.py --stl libc++ --arch $SDK_ARCH --api $ANDROID_VERSION --install-dir="$bld_root/toolchain" &>/dev/null
            fi
            export SDK_PLATFORM=$(basename $(find $bld_root/toolchain/ -maxdepth 1 -type d -name "*linux-android*"))
            export AR="$bld_root/toolchain/bin/$SDK_PLATFORM-ar"
            export RANLIB="$bld_root/toolchain/bin/$SDK_PLATFORM-ranlib"
            ./tools/make_txt.sh $bld_root $bld_root/$1_$2_ndk.txt $1 ndk
            meson $bld_root --cross-file $bld_root/$1_$2_ndk.txt --default-library=${LIBTYPE} --buildtype=release
        fi
        cd $bld_root 
        $NINJA -j$NUM_JOBS -v
        cd ..
    }

    if [ -n "$2" ]; then
        all_archs="$2"
    else
        all_archs="armeabi armeabi-v7a arm64-v8a mips mips64 x86 x86_64"
    fi
    for a in $all_archs; do
        set_cross_build_env android $a
        build android $a
    done
fi

if [ \( "$(uname)" = "Darwin" \) -a \( $# -eq 0 \) -o \( "$1" = "--iphone" \) -o \( "$1" = "--iphonesim" \) ]; then

    function build() {
        bld_root="$PWD/build-clang-$1-$2"

        if test "x$2" == "xiphone"; then
            export IOS_PLATFORM=iPhoneOS
        else
            export IOS_PLATFORM=iPhoneSimulator
        fi
        export XCODE_PATH=$(xcode-select --print-path 2>/dev/null)
        export XCODE_DEFAULT_PATH="$XCODE_PATH/Toolchains/XcodeDefault.xctoolchain/usr/bin"
        export XCODE_IOS_PATH="$XCODE_PATH/Platforms/$IOS_PLATFORM.platform/Developer/usr/bin"
        export IOS_SDK_PATH="$XCODE_PATH/Platforms/$IOS_PLATFORM.platform/Developer/SDKs/$IOS_PLATFORM.sdk"

        export PATH=$XCODE_DEFAULT_PATH:$XCODE_IOS_PATH:$PATH_BASE

        if test "x$2" == "xiphone"; then
            export ARCHS="-arch armv7 -arch armv7s -arch arm64"
        else
            export ARCHS="-arch i386 -arch x86_64"
        fi

        export SDK_CFLAGS_NO_ARCH="$SDK_CFLAGS"
        export SDK_CFLAGS="$SDK_CFLAGS $ARCHS"
        export SDK_CPPFLAGS="$SDK_CFLAGS"
        export SDK_LDFLAGS="$SDK_CFLAGS"

        export AR=ar

        if [ ! -f "build-clang-$1-$2/build.ninja" ]; then
            rm -rf build-clang-$1-$2/meson-private
            ./tools/make_txt.sh $bld_root $bld_root/$1_$2_ios.txt $2 $2
            meson $bld_root --cross-file $bld_root/$1_$2_ios.txt --default-library=${LIBTYPE} --buildtype=release
        fi
        cd $bld_root
        $NINJA -j$NUM_JOBS -v
        cd ..
    }

    if test "x$1" == "x--iphone"; then
        PLATFORM=iphone
    else
        PLATFORM=iphonesim
    fi
    set_cross_build_env ios $PLATFORM
    build ios $PLATFORM
fi

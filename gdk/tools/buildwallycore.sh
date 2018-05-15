#! /usr/bin/env bash
set -e

WALLYCORE_NAME="libwally-core-987575025520d18bac31e6e2d27c8c936d812c64"

cp -r "${MESON_SOURCE_ROOT}/subprojects/${WALLYCORE_NAME}" "${MESON_BUILD_ROOT}/libwally-core"

if [ "$(uname)" == "Darwin" ]; then
    export HOST_OS="x86_64-apple-darwin"
    SED=gsed
else
    export HOST_OS="i686-linux-gnu"
    SED=sed
fi

ENABLE_SWIG_JAVA=disable-swig-java
if [ "x$JAVA_HOME" != "x" ]; then
    ENABLE_SWIG_JAVA=enable-swig-java
fi

cd "${MESON_BUILD_ROOT}/libwally-core"
./tools/cleanup.sh
./tools/autogen.sh

$SED -i 's/\"wallycore\"/\"greenaddress\"/' ${MESON_BUILD_ROOT}/libwally-core/src/swig_java/swig.i

if [ \( "$1" = "--ndk" \) ]; then
    . ${MESON_SOURCE_ROOT}/tools/env.sh
    . tools/android_helpers.sh

    export CFLAGS="$SDK_CFLAGS -DPIC -fPIC"

    android_build_wally $HOST_ARCH "${MESON_BUILD_ROOT}/toolchain" $ANDROID_VERSION --host=$SDK_PLATFORM --build=$HOST_OS \
          --enable-static --disable-shared --$ENABLE_SWIG_JAVA --target=$SDK_PLATFORM --prefix="${MESON_BUILD_ROOT}/libwally-core/build"

    make -o configure install
elif [ \( "$1" = "--iphone" \) -o \( "$1" = "--iphonesim" \) ]; then
    export CFLAGS="$SDK_CFLAGS -fembed-bitcode -isysroot ${IOS_SDK_PATH} -miphoneos-version-min=9.0 -O3"
    export LDFLAGS="$SDK_LDFLAGS -isysroot ${IOS_SDK_PATH} -miphoneos-version-min=9.0"
    export CC=${XCODE_DEFAULT_PATH}/clang
    export CXX=${XCODE_DEFAULT_PATH}/clang++
    ./configure --host=armv7-apple-darwin --with-sysroot=${IOS_SDK_PATH} --build=$HOST_OS \
                --enable-static --disable-shared --prefix="${MESON_BUILD_ROOT}/libwally-core/build"
    make -o configure clean -j$NUM_JOBS
    make -o configure -j$NUM_JOBS
    make -o configure install
else
    export CFLAGS="$SDK_CFLAGS -DPIC -fPIC"

    ./configure --$ENABLE_SWIG_JAVA --host=$HOST_OS --enable-static --disable-shared --prefix="${MESON_BUILD_ROOT}/libwally-core/build"

    make -j$NUM_JOBS
    make install
fi

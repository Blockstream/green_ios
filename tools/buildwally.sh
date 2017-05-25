#! /usr/bin/env bash
set -e
if [ "$(uname)" == "Darwin" ]; then
    export HOST_OS="x86_64-apple-darwin"
else
    export HOST_OS="i686-linux-gnu"
fi
cd "${MESON_BUILD_ROOT}/wallycore"
./tools/cleanup.sh
./tools/autogen.sh
if [ \( "$1" = "--ndk" \) ]; then
    . ${MESON_SOURCE_ROOT}/tools/env.sh
    ./configure --host=$SDK_PLATFORM --with-sysroot="${MESON_BUILD_ROOT}/toolchain/sysroot" --build=$HOST_OS --enable-silent-rules --disable-dependency-tracking --target=$SDK_PLATFORM --prefix="${MESON_BUILD_ROOT}/libwally-core/build"
    make -o configure clean -j$NUM_JOBS
    make -o configure -j$NUM_JOBS V=1
    make -o configure install
elif [ \( "$1" = "--iphone" \) ]; then
    export CFLAGS="$SDK_CFLAGS -isysroot ${IPHONE_SDK_PATH} -miphoneos-version-min=9.0 -O3"
    export LDFLAGS="$SDK_LDFLAGS -isysroot ${IPHONE_SDK_PATH} -miphoneos-version-min=9.0"
    export CPPFLAGS=${CFLAGS}
    export CC=${XCODE_DEFAULT_PATH}/clang
    export CXX=${XCODE_DEFAULT_PATH}/clang++
    ./configure --host=armv7-apple-darwin --with-sysroot=${IPHONE_SDK_PATH} --build=$HOST_OS --enable-silent-rules --disable-dependency-tracking --target=armv7 --prefix="${MESON_BUILD_ROOT}/libwally-core/build"
    make -o configure clean -j$NUM_JOBS
    make -o configure -j$NUM_JOBS V=1
    make -o configure install
else
    ./configure --enable-silent-rules --disable-dependency-tracking --prefix="${MESON_BUILD_ROOT}/libwally-core/build"
    make -j$NUM_JOBS
    make install
fi

#! /usr/bin/env bash
set -e

if [ "$(uname)" == "Darwin" ]; then
    export HOST_OS="x86_64-apple-darwin"
else
    export HOST_OS="i686-linux-gnu"
fi
cd "${MESON_SOURCE_ROOT}/src/wally"
./tools/cleanup.sh
./tools/autogen.sh
if [ \( "$1" = "--arm" \) ]; then
    export PATH="${MESON_BUILD_ROOT}/toolchain/bin:${PATH}"
    export CFLAGS="-march=armv7-a -mfloat-abi=softfp -mfpu=neon -mthumb -O3"
    export LDFLAGS="-Wl,--fix-cortex-a8"
    export CPPFLAGS="$CFLAGS"
    export CC=clang
    export AR="${MESON_BUILD_ROOT}/toolchain/bin/arm-linux-androideabi-ar"
    export RANLIB="${MESON_BUILD_ROOT}/toolchain/bin/arm-linux-androideabi-ranlib"
    ./configure --host=arm-linux-androideabi --build=$HOST_OS --enable-silent-rules --disable-dependency-tracking --target=arm-linux-androideabi --prefix="${MESON_BUILD_ROOT}/thirdparty/libwally-core/build"
    make -o configure clean -j$NUM_JOBS
    make -o configure -j$NUM_JOBS V=1
    make -o configure install
else
    ./configure --enable-silent-rules --disable-dependency-tracking --prefix="${MESON_BUILD_ROOT}/thirdparty/libwally-core/build"
    make -j$NUM_JOBS
    make install
fi

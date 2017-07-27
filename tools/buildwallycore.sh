#! /usr/bin/env bash
set -e

if [ "$(uname)" == "Darwin" ]; then
    export HOST_OS="x86_64-apple-darwin"
    SED=gsed
else
    export HOST_OS="i686-linux-gnu"
    SED=sed
fi

ENABLE_SWIG_JAVA=disable-swig-java
if [ "x$JAVA_HOME" != "x" -a "$(uname)" != "Darwin" ]; then
    ENABLE_SWIG_JAVA=enable-swig-java
fi

cd "${MESON_BUILD_ROOT}/libwally-core"
./tools/cleanup.sh
./tools/autogen.sh

$SED -i 's/\"wallycore\"/\"greenaddress\"/' ${MESON_BUILD_ROOT}/libwally-core/src/swig_java/swig.i

if [ \( "$1" = "--ndk" \) ]; then
    . ${MESON_SOURCE_ROOT}/tools/env.sh
    export CFLAGS="$SDK_CFLAGS -fPIC -O3"
    export AR="${MESON_BUILD_ROOT}/toolchain/bin/$SDK_PLATFORM-ar"
    export RANLIB=true

    LTO=enable-lto
    if test "x$SDK_ARCH" == "xarm64" || test "x$SDK_ARCH" == "xmips"; then
        LTO=disable-lto
    fi

    ./configure --host=$SDK_PLATFORM --with-sysroot="${MESON_BUILD_ROOT}/toolchain/sysroot" --build=$HOST_OS --enable-silent-rules --$ENABLE_SWIG_JAVA \
                --disable-shared --disable-dependency-tracking --target=$SDK_PLATFORM --$LTO --prefix="${MESON_BUILD_ROOT}/libwally-core/build"
    make -o configure clean -j$NUM_JOBS
    make -o configure -j$NUM_JOBS
    make -o configure install
elif [ \( "$1" = "--iphone" \) -o \( "$1" = "--iphonesim" \) ]; then
    export CFLAGS="$SDK_CFLAGS -fembed-bitcode -isysroot ${IOS_SDK_PATH} -miphoneos-version-min=9.0 -O3"
    export LDFLAGS="$SDK_LDFLAGS -isysroot ${IOS_SDK_PATH} -miphoneos-version-min=9.0"
    export CC=${XCODE_DEFAULT_PATH}/clang
    export CXX=${XCODE_DEFAULT_PATH}/clang++
    export AR="libtool"
    export AR_FLAGS="-static -o"
    ./configure --host=armv7-apple-darwin --with-sysroot=${IOS_SDK_PATH} --build=$HOST_OS --enable-silent-rules \
                --disable-shared --disable-dependency-tracking --prefix="${MESON_BUILD_ROOT}/libwally-core/build"
    make -o configure clean -j$NUM_JOBS
    make -o configure -j$NUM_JOBS
    make -o configure install
else
    if [ "$(uname)" == "Darwin" ]; then
        export AR="libtool"
        export AR_FLAGS="-static -o"
    fi
    export CFLAGS="$SDK_CFLAGS -fPIC -O3"
    if test "x$(uname)" != "xDarwin" && test "x$CC" == "xclang"; then
        export AR=llvm-ar
        export RANLIB=llvm-ranlib
    fi

    ./configure --enable-silent-rules --$ENABLE_SWIG_JAVA --disable-shared --disable-dependency-tracking --prefix="${MESON_BUILD_ROOT}/libwally-core/build"
    make -j$NUM_JOBS
    make install
fi

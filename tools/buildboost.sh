#! /usr/bin/env bash
set -e
boost_src_home="${MESON_BUILD_ROOT}/boost_1_64_0"
boost_bld_home="${MESON_BUILD_ROOT}/boost_1_64_0/build"
cd $boost_src_home
cp "${MESON_SOURCE_ROOT}/tools/clang.jam" "$boost_src_home/tools/build/src/tools"
if [ \( "$1" = "--ndk" \) ]; then
    export TARGET_OS=android
    . ${MESON_SOURCE_ROOT}/tools/env.sh
    rm -fr $boost_src_home/user-config.jam
    echo "using clang : $SDK_ARCH : ${SDK_PLATFORM}-clang++ : --sysroot=$SYSROOT ;" > $boost_src_home/user-config.jam
    ./bootstrap.sh --prefix="$boost_bld_home" --with-libraries=system,thread
    ./b2 --clean
    ./b2 -j$NUM_JOBS --with-thread --with-system toolset=clang-${SDK_ARCH} target-os=android install
else
    ./bootstrap.sh --prefix="$boost_bld_home" --with-libraries=system,thread
    ./b2 --clean
    ./b2 -j$NUM_JOBS --with-thread --with-system install
fi

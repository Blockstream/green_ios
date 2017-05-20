#! /usr/bin/env bash
set -e
boost_src_home="${MESON_SOURCE_ROOT}/thirdparty/boost_1_64_0"
boost_bld_home="${MESON_BUILD_ROOT}/thirdparty/boost_1_64_0/build"
cd $boost_src_home
cp "${MESON_SOURCE_ROOT}/tools/clang.jam" "$boost_src_home/tools/build/src/tools"
if [ \( "$1" = "--ndk" \) ]; then
    export TARGET_OS=android
    . ${MESON_SOURCE_ROOT}/tools/env.sh
    echo "using clang : arm : arm-linux-androideabi-clang++ : --sysroot=$SYSROOT ;" > $boost_src_home/user-config.jam
    ./bootstrap.sh --prefix="$boost_bld_home" --with-libraries=system,thread
    ./b2 --clean
    ./b2 -j$NUM_JOBS --with-thread --with-system toolset=clang-arm target-os=android install
else
    ./bootstrap.sh --prefix="$boost_bld_home" --with-libraries=system,thread
    ./b2 --clean
    ./b2 -j$NUM_JOBS --with-thread --with-system install
fi

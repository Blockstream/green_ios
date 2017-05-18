#! /usr/bin/env bash
set -e
cd "${MESON_SOURCE_ROOT}/thirdparty/boost_1_64_0"
cp "${MESON_SOURCE_ROOT}/tools/user-config.jam" "${MESON_SOURCE_ROOT}/thirdparty/boost_1_64_0"
cp "${MESON_SOURCE_ROOT}/tools/clang.jam" "${MESON_SOURCE_ROOT}/thirdparty/boost_1_64_0/tools/build/src/tools"
./bootstrap.sh --prefix="${MESON_BUILD_ROOT}/thirdparty/boost_1_64_0/build"
./b2 --clean
if [ \( "$1" = "--arm" \) ]; then
    export PATH="${MESON_BUILD_ROOT}/toolchain/bin:$PATH"
    export TARGET_OS=android
    ./b2 -j$NUM_JOBS --with-thread --with-system toolset=clang-arm target-os=android install
else
    ./b2 -j$NUM_JOBS --with-thread --with-system install
fi

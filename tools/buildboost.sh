#! /usr/bin/env bash
set -e

cd "${MESON_SOURCE_ROOT}/thirdparty/boost_1_64_0"
cp "${MESON_SOURCE_ROOT}/tools/user-config.jam" "${MESON_SOURCE_ROOT}/thirdparty/boost_1_64_0"
./bootstrap.sh --prefix="${MESON_BUILD_ROOT}/thirdparty/boost_1_64_0/build"
./b2 --clean
if [ \( "$1" = "--arm" \) ]; then
    export PATH=$PATH:"${MESON_SOURCE_ROOT}/toolchain/bin"
    ./b2 -j$NUM_JOBS --with-thread --with-system --toolset=clang-arm --target-os=android install
else
    ./b2 -j$NUM_JOBS --with-thread --with-system install
fi

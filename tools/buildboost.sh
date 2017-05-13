#! /usr/bin/env bash
set -e

cd "${MESON_SOURCE_ROOT}/thirdparty/boost_1_64_0"
./bootstrap.sh --prefix="${MESON_BUILD_ROOT}/thirdparty/boost_1_64_0/build"
./b2 -j$NUM_JOBS --with-thread --with-system install


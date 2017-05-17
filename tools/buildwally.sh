#! /usr/bin/env bash
set -e

cd "${MESON_SOURCE_ROOT}/src/wally"
./tools/cleanup.sh
./tools/autogen.sh
./configure --prefix="${MESON_BUILD_ROOT}/thirdparty/libwally-core/build"
make -j$NUM_JOBS
make install

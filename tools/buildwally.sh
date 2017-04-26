#! /usr/bin/env bash
set -e

cd "${MESON_SOURCE_ROOT}/src/wally"
./tools/cleanup.sh
./tools/autogen.sh
./configure
make -j$NUM_JOBS

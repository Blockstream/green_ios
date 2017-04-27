#! /usr/bin/env bash
set -e

cd "${MESON_SOURCE_ROOT}/src/wally"
./tools/autogen.sh
./configure
make

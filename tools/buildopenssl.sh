#! /usr/bin/env bash
set -e

cd "${MESON_SOURCE_ROOT}/thirdparty/openssl-1.0.2k"
./config --prefix="${MESON_SOURCE_ROOT}/thirdparty/openssl-1.0.2k/build" shared
make depend
make -j$NUM_JOBS
make install


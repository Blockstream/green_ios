#! /usr/bin/env bash
set -e

rm -fr $MESON_SOURCE_ROOT/thirdparty/openssl-1.0.2k/build

cd "${MESON_SOURCE_ROOT}/thirdparty/openssl-1.0.2k"

if [ "$(uname)" == "Darwin" ]; then
    ./Configure darwin64-x86_64-cc --prefix="${MESON_SOURCE_ROOT}/thirdparty/openssl-1.0.2k/build" shared
else
    ./config --prefix="${MESON_SOURCE_ROOT}/thirdparty/openssl-1.0.2k/build" shared
fi

make depend
make -j$NUM_JOBS
make install


#! /usr/bin/env bash
set -e
cd "${MESON_SOURCE_ROOT}/thirdparty/openssl-1.0.2k"

if [ \( "$1" = "--arm" \) ]; then
    export PATH="${MESON_BUILD_ROOT}/toolchain/bin:${PATH}"
    export CC=clang
    if [ "$(uname)" == "Darwin" ]; then
        gsed -i 's/-mandroid//g' ${MESON_SOURCE_ROOT}/thirdparty/openssl-1.0.2k/Configure
    else
        sed -i 's/-mandroid//g' ${MESON_SOURCE_ROOT}/thirdparty/openssl-1.0.2k/Configure
    fi
    ./Configure android -march=armv7-a --prefix="${MESON_BUILD_ROOT}/thirdparty/openssl-1.0.2k/build" no-krb5  shared
else
    if [ "$(uname)" == "Darwin" ]; then
        ./Configure darwin64-x86_64-cc --prefix="${MESON_BUILD_ROOT}/thirdparty/openssl-1.0.2k/build" shared
    else
        ./config --prefix="${MESON_BUILD_ROOT}/thirdparty/openssl-1.0.2k/build" shared
    fi
fi

make clean
make depend
make
make install_sw


#! /usr/bin/env bash
set -e
cd "${MESON_SOURCE_ROOT}/thirdparty/openssl-1.0.2k"
openssl_prefix="${MESON_BUILD_ROOT}/thirdparty/openssl-1.0.2k/build"
if [ \( "$1" = "--arm" \) ]; then
    if [ "$(uname)" == "Darwin" ]; then
        gsed -i 's/-mandroid//g' ${MESON_SOURCE_ROOT}/thirdparty/openssl-1.0.2k/Configure
    else
        sed -i 's/-mandroid//g' ${MESON_SOURCE_ROOT}/thirdparty/openssl-1.0.2k/Configure
    fi
    . ${MESON_SOURCE_ROOT}/tools/env.sh
    ./Configure android -march=armv7-a --prefix="$openssl_prefix" no-krb5  shared
else
    if [ "$(uname)" == "Darwin" ]; then
        ./Configure darwin64-x86_64-cc --prefix="$openssl_prefix" shared
    else
        ./config --prefix="$openssl_prefix" shared
    fi
fi

make clean
make depend
make
make install_sw


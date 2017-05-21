#! /usr/bin/env bash
set -e
cd "${MESON_BUILD_ROOT}/openssl-1.0.2k"
openssl_prefix="${MESON_BUILD_ROOT}/openssl-1.0.2k/build"
if [ \( "$1" = "--ndk" \) ]; then
    if [ "$(uname)" == "Darwin" ]; then
        gsed -i 's/-mandroid//g' ${MESON_BUILD_ROOT}/openssl-1.0.2k/Configure
    else
        sed -i 's/-mandroid//g' ${MESON_BUILD_ROOT}/openssl-1.0.2k/Configure
    fi
    . ${MESON_SOURCE_ROOT}/tools/env.sh
    ./Configure android --prefix="$openssl_prefix" no-krb5 shared
else
    if [ "$(uname)" == "Darwin" ]; then
        ./Configure darwin64-x86_64-cc --prefix="$openssl_prefix" shared
    else
        ./config --prefix="$openssl_prefix" shared
    fi
fi

make clean
make depend
make 2> /dev/null
make install_sw


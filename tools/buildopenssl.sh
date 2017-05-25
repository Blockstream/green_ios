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
elif [ \( "$1" = "--iphone" \) ]; then
    export CC=${XCODE_DEFAULT_PATH}/clang
    export CROSS_TOP="${XCODE_PATH}/Platforms/iPhoneOS.platform/Developer"
    export CROSS_SDK="iPhoneOS.sdk"
    export PATH="${XCODE_DEFAULT_PATH}:$PATH"
    ./Configure iphoneos-cross no-shared no-dso no-hw no-engine --prefix="$openssl_prefix"
    sed -ie "s!^CFLAG=!CFLAG=-isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -arch armv7 -miphoneos-version-min=9.0 !" "Makefile"
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


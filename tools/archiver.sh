#! /usr/bin/env bash
set -e

if test "x$1" == "x--iphone" || test "x$1" == "x--iphonesim"; then

    boost_system_lib=$2/boost/build/lib/libboost_system
    boost_thread_lib=$2/boost/build/lib/libboost_thread
    greenaddress_lib=$2/src/libgreenaddress
    openssl_crypto_lib=$2/openssl/build/lib/libcrypto
    openssl_ssl_lib=$2/openssl/build/lib/libssl
    secp256k1_lib=$2/libwally-core/build/lib/libsecp256k1
    wally_lib=$2/libwally-core/build/lib/libwallycore

    if test "x$1" == "x--iphonesim"; then
        all_archs="i386 x86_64"
    else
        all_archs="armv7 armv7s arm64"
    fi

    libgreenaddress_for_arch=""
    libraries="$boost_system_lib $boost_thread_lib $greenaddress_lib $openssl_crypto_lib $openssl_ssl_lib $secp256k1_lib $wally_lib"
    for arch in $all_archs; do
        libraries_for_arch=""
        for lib in $libraries; do
            basename=`basename $lib`
            lipo -extract $arch ${lib}.a -o $2/src/${basename}_${arch}.a
            libraries_for_arch="$libraries_for_arch $2/src/${basename}_${arch}.a"
        done

        libtool -static $libraries_for_arch -o $2/src/single_arch_libgreenaddress_$arch.a
        libgreenaddress_for_arch="$libgreenaddress_for_arch $2/src/single_arch_libgreenaddress_$arch.a"
    done

    lipo -create $libgreenaddress_for_arch -o $2/src/libgreenaddress.a
fi

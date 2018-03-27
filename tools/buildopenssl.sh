#! /usr/bin/env bash
set -e
cd "${MESON_BUILD_ROOT}/openssl-1.0.2o"
openssl_prefix="${MESON_BUILD_ROOT}/openssl-1.0.2o/build"
if [ \( "$1" = "--ndk" \) ]; then
    if [ "$(uname)" == "Darwin" ]; then
        gsed -i 's/-mandroid//g' ${MESON_BUILD_ROOT}/openssl-1.0.2o/Configure
    else
        sed -i 's/-mandroid//g' ${MESON_BUILD_ROOT}/openssl-1.0.2o/Configure
    fi
    . ${MESON_SOURCE_ROOT}/tools/env.sh
    ./Configure android --prefix="$openssl_prefix" no-krb5 no-shared no-dso
    sed -ie "s!-ldl!!" "Makefile"
    make depend
    make 2> /dev/null
    make install_sw
elif [ \( "$1" = "--iphone" \) -o \( "$1" = "--iphonesim" \) ]; then
    export CC=${XCODE_DEFAULT_PATH}/clang
    export CROSS_TOP="${XCODE_PATH}/Platforms/${IOS_PLATFORM}.platform/Developer"
    export CROSS_SDK="${IOS_PLATFORM}.sdk"
    export PATH="${XCODE_DEFAULT_PATH}:$PATH"
    if test "x$1" == "x--iphonesim"; then
        all_archs="i386 x86_64" 
    else
        all_archs="armv7 armv7s arm64"
    fi
    for arch in $all_archs; do
	export CURRENT_ARCH=$arch
	ARCH_BITS=32
        NOASM=
	if test "x$arch" == "arm64" || test "x$arch" == "xx86_64"; then
	    ARCH_BITS=64
        fi

        if test "x$arch" == "i386" || test "x$arch" == "xx86_64"; then
            NOASM=no-asm
	fi
        KERNEL_BITS=$ARCH_BITS ./Configure iphoneos-cross no-krb5 no-shared no-dso no-hw no-engine $NOASM --prefix=$openssl_prefix
        sed -ie "s!-fomit-frame-pointer!!" "Makefile"
        sed -ie "s!^CFLAG=!CFLAG=-fembed-bitcode -isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -arch ${CURRENT_ARCH} -miphoneos-version-min=9.0 !" "Makefile"
        make clean
        make depend
        make 2> /dev/null
        make install_sw
	mkdir -p build-$arch/tmp/$arch
        mv $openssl_prefix/* build-$arch/tmp/$arch
    done
    mkdir -p $openssl_prefix
    cp -R build-$arch/tmp/$arch/* $openssl_prefix
    for arch in $all_archs; do
        cp build-$arch/tmp/$arch/include/openssl/opensslconf.h $openssl_prefix/include/openssl/opensslconf-$arch.h
        cp build-$arch/tmp/$arch/include/openssl/bn.h $openssl_prefix/include/openssl/bn-$arch.h
    done

    if test "x$1" == "x--iphonesim"; then
        cat > $openssl_prefix/include/openssl/opensslconf.h << EOF
#if __i386__
#include "opensslconf-i386.h"
#elif __x86_64
#include "opensslconf-x86_64.h"
#else
#error unsupported architecture
#endif
EOF
        cat > $openssl_prefix/include/openssl/bn.h << EOF
#ifndef OPENSSL_MULTIARCH_BN_H
#define OPENSSL_MULTIARCH_BN_H

#if __i386
#include "bn-i386.h"
#elif __x86_64
#include "bn-x86_64.h"
#else
#error unsupported architecture
#endif
#endif
EOF
        lipo -create build-i386/tmp/i386/lib/libcrypto.a \
	             build-x86_64/tmp/x86_64/lib/libcrypto.a \
             -output $openssl_prefix/lib/libcrypto.a
        lipo -create build-i386/tmp/i386/lib/libssl.a \
	             build-x86_64/tmp/x86_64/lib/libssl.a \
         -output $openssl_prefix/lib/libssl.a
    else
        cat > $openssl_prefix/include/openssl/opensslconf.h << EOF
#if __ARM_ARCH_7A__
#include "opensslconf-armv7.h"
#elif __ARM_ARCH_7S__
#include "opensslconf-armv7s.h"
#elif __ARM_ARCH_ISA_A64
#include "opensslconf-arm64.h"
#else
#error unsupported architecture
#endif
EOF
        cat > $openssl_prefix/include/openssl/bn.h << EOF
#ifndef OPENSSL_MULTIARCH_BN_H
#define OPENSSL_MULTIARCH_BN_H

#if __ARM_ARCH_7A__
#include "bn-armv7.h"
#elif __ARM_ARCH_7S__
#include "bn-armv7s.h"
#elif __ARM_ARCH_ISA_A64
#include "bn-arm64.h"
#else
#error unsupported architecture
#endif
#endif
EOF
        lipo -create build-armv7/tmp/armv7/lib/libcrypto.a \
	             build-armv7s/tmp/armv7s/lib/libcrypto.a \
		     build-arm64/tmp/arm64/lib/libcrypto.a \
             -output $openssl_prefix/lib/libcrypto.a
        lipo -create build-armv7/tmp/armv7/lib/libssl.a \
	             build-armv7s/tmp/armv7s/lib/libssl.a \
		     build-arm64/tmp/arm64/lib/libssl.a \
             -output $openssl_prefix/lib/libssl.a
    fi
else
    if [ "$(uname)" == "Darwin" ]; then
        ./Configure darwin64-x86_64-cc --prefix="$openssl_prefix" no-shared
    else
        ./config --prefix="$openssl_prefix" no-shared
        sed -ie "s!^CFLAG=!CFLAG=-fPIC -DPIC !" "Makefile"
    fi
    make depend
    make -j$NUM_JOBS 2> /dev/null
    make install_sw
fi


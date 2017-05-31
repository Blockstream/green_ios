#!/usr/bin/env bash
set -e

SHA256SUM_AUTOBAHN=612e0f9fea274ee7a2b3873c7ab86ba82c5ed24a4aa4f125cdeb155c21656dca
SHA256SUM_WEBSOCKETPP=07b3364ad30cda022d91759d4b83ff902e1ebadb796969e58b59caa535a03923
SHA256SUM_MSGPACK=fce702408f0d228a1b9dcab69590d6a94d3938f694b95c9e5e6249617e98d83f
SHA256SUM_WALLYCORE=83a3699ba8ba767c3d48e8085853be8b9ca6fc921b37c9ea95ecd78bdf681251
SHA256SUM_BOOST=0445c22a5ef3bd69f5dfb48354978421a85ab395254a26b1ffb0aa1bfd63a108
SHA256SUM_OPENSSL=a3d3a7c03c90ba370405b2d12791598addfcafb1a77ef483c02a317a56c08485

SHASUM=sha256sum

if [ "$(uname)" == "Darwin" ]; then
    SHASUM="shasum -a 256"
fi

DEPS_BLD_DIR=$1

if [ ! -d "deps_cache" ]; then
  mkdir deps_cache
fi

if [ ! -d "$DEPS_BLD_DIR" ]; then
  mkdir $DEPS_BLD_DIR
fi

function prepare_pkg() {
    if [ ! -d "$DEPS_BLD_DIR/$1" ]; then
        if [ ! -f "deps_cache/$1_$3.tar.gz" ]; then
            wget -q -O deps_cache/$1_$3.tar.gz $2
        fi
        echo "$3  deps_cache/$1_$3.tar.gz" | $SHASUM --check
        tar -zxf deps_cache/$1_$3.tar.gz -C $DEPS_BLD_DIR/
    fi
}

prepare_pkg autobahn-cpp https://github.com/crossbario/autobahn-cpp/archive/e2d4c8186bc6f3c81f1638b07ad68fcc250c4dfb.tar.gz ${SHA256SUM_AUTOBAHN}
prepare_pkg websocketpp-0.7.0 https://github.com/zaphoyd/websocketpp/archive/0.7.0.tar.gz ${SHA256SUM_WEBSOCKETPP}
prepare_pkg msgpack-2.1.1 https://github.com/msgpack/msgpack-c/releases/download/cpp-2.1.1/msgpack-2.1.1.tar.gz ${SHA256SUM_MSGPACK}
prepare_pkg boost_1_64_0 https://dl.bintray.com/boostorg/release/1.64.0/source/boost_1_64_0.tar.gz ${SHA256SUM_BOOST}
prepare_pkg openssl-1.0.2l https://github.com/openssl/openssl/archive/OpenSSL_1_0_2l.tar.gz ${SHA256SUM_OPENSSL}
prepare_pkg wallycore https://github.com/jgriffiths/libwally-core/archive/30a3124fca42adce82c837385eb6de0331d12af8.tar.gz ${SHA256SUM_WALLYCORE}

function move_if() {
    if [ ! -d "$DEPS_BLD_DIR/$2" ]; then
        mv $DEPS_BLD_DIR/$1 $DEPS_BLD_DIR/$2
    fi
}
move_if *autobahn* autobahn-cpp
move_if openssl* openssl-1.0.2l
move_if libwally-core-30a3124fca42adce82c837385eb6de0331d12af8* libwally-core

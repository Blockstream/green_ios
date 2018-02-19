#!/usr/bin/env bash
set -e

SHA256SUM_AUTOBAHN=612e0f9fea274ee7a2b3873c7ab86ba82c5ed24a4aa4f125cdeb155c21656dca
SHA256SUM_WEBSOCKETPP=07b3364ad30cda022d91759d4b83ff902e1ebadb796969e58b59caa535a03923
SHA256SUM_MSGPACK=beaac1209f33276b5a75e7a02f8689ed44b97209cef82ba0909e06f0c45f6cae
SHA256SUM_WALLYCORE=4df42cbc360813dedb4b3727bbee662aef5cc7e4120783380a91024c4f06abe6
SHA256SUM_BOOST=0445c22a5ef3bd69f5dfb48354978421a85ab395254a26b1ffb0aa1bfd63a108
SHA256SUM_OPENSSL=9066c68c1aa8e8719af61cb82b88156ab07b3ad2a9ab1f874a8afb324583b1b6

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
prepare_pkg msgpack-2.1.3 https://github.com/msgpack/msgpack-c/releases/download/cpp-2.1.3/msgpack-2.1.3.tar.gz ${SHA256SUM_MSGPACK}
prepare_pkg boost_1_64_0 https://dl.bintray.com/boostorg/release/1.64.0/source/boost_1_64_0.tar.gz ${SHA256SUM_BOOST}
prepare_pkg openssl-1.0.2m https://github.com/openssl/openssl/archive/OpenSSL_1_0_2m.tar.gz ${SHA256SUM_OPENSSL}
prepare_pkg libwally-core https://github.com/jgriffiths/libwally-core/archive/txs.tar.gz ${SHA256SUM_WALLYCORE}

function move_if() {
    if [ ! -d "$DEPS_BLD_DIR/$2" ]; then
        mv $DEPS_BLD_DIR/$1 $DEPS_BLD_DIR/$2
    fi
}
move_if *autobahn* autobahn-cpp
move_if openssl* openssl-1.0.2m
move_if *msgpack* msgpack
move_if libwally-core-* libwally-core

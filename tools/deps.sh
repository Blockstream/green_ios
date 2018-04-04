#!/usr/bin/env bash
set -e

SHA256SUM_AUTOBAHN=0d70e8a62d3958d959e84cbac6d6f8a54177b1c768e0aa5b4ab218963fc2e350
SHA256SUM_WEBSOCKETPP=07b3364ad30cda022d91759d4b83ff902e1ebadb796969e58b59caa535a03923
SHA256SUM_MSGPACK=6126375af9b204611b9d9f154929f4f747e4599e6ae8443b337915dcf2899d2b
SHA256SUM_WALLYCORE=df1e23a315bdd05d15d5099f20b2576bbcfee939cbf734b09861ac42cd9ec85d
SHA256SUM_BOOST=bd0df411efd9a585e5a2212275f8762079fed8842264954675a4fddc46cfcf60
SHA256SUM_OPENSSL=fd8bff81636c262ff82cb22286957d73213f899c1a80a3ec712c7ae80761ea9b

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

prepare_pkg autobahn-cpp https://github.com/crossbario/autobahn-cpp/archive/2325b7ac4aa7d8812e9902772b1fa6baef4c58e7.tar.gz ${SHA256SUM_AUTOBAHN}
prepare_pkg websocketpp-0.7.0 https://github.com/zaphoyd/websocketpp/archive/0.7.0.tar.gz ${SHA256SUM_WEBSOCKETPP}
prepare_pkg msgpack-2.1.5 https://github.com/msgpack/msgpack-c/releases/download/cpp-2.1.5/msgpack-2.1.5.tar.gz ${SHA256SUM_MSGPACK}
prepare_pkg boost_1_66_0 https://dl.bintray.com/boostorg/release/1.66.0/source/boost_1_66_0.tar.gz ${SHA256SUM_BOOST}
prepare_pkg openssl-1.0.2o https://github.com/openssl/openssl/archive/OpenSSL_1_0_2o.tar.gz ${SHA256SUM_OPENSSL}
prepare_pkg libwally-core https://github.com/jgriffiths/libwally-core/archive/txs.tar.gz ${SHA256SUM_WALLYCORE}

function move_if() {
    if [ ! -d "$DEPS_BLD_DIR/$2" ]; then
        mv $DEPS_BLD_DIR/$1 $DEPS_BLD_DIR/$2
    fi
}
move_if *autobahn* autobahn-cpp
move_if openssl* openssl-1.0.2o
move_if *msgpack* msgpack
move_if libwally-core-* libwally-core

cp tools/wamp_arguments.hpp $DEPS_BLD_DIR/autobahn-cpp/autobahn

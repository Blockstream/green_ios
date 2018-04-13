#!/usr/bin/env bash
set -e

SHA256SUM_AUTOBAHN=41733e7c8287c31126e973bb1056a83236cd5bbb9507053a5a84e78f57791b90
SHA256SUM_WEBSOCKETPP=07b3364ad30cda022d91759d4b83ff902e1ebadb796969e58b59caa535a03923
SHA256SUM_MSGPACK=6126375af9b204611b9d9f154929f4f747e4599e6ae8443b337915dcf2899d2b
SHA256SUM_WALLYCORE=40c98d61ba576b6149fd56822a3bc7c5c3db8919550737e3a3360132efb25a6c
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

prepare_pkg autobahn-cpp https://github.com/crossbario/autobahn-cpp/archive/cd74d3ccd7b600e4fef6e1c4cbe584ffd91048f5.tar.gz ${SHA256SUM_AUTOBAHN}
prepare_pkg websocketpp-0.7.0 https://github.com/zaphoyd/websocketpp/archive/0.7.0.tar.gz ${SHA256SUM_WEBSOCKETPP}
prepare_pkg msgpack-2.1.5 https://github.com/msgpack/msgpack-c/releases/download/cpp-2.1.5/msgpack-2.1.5.tar.gz ${SHA256SUM_MSGPACK}
prepare_pkg boost_1_66_0 https://dl.bintray.com/boostorg/release/1.66.0/source/boost_1_66_0.tar.gz ${SHA256SUM_BOOST}
prepare_pkg openssl-1.0.2o https://github.com/openssl/openssl/archive/OpenSSL_1_0_2o.tar.gz ${SHA256SUM_OPENSSL}
prepare_pkg libwally-core https://github.com/ElementsProject/libwally-core/archive/987575025520d18bac31e6e2d27c8c936d812c64.tar.gz ${SHA256SUM_WALLYCORE}

function move_if() {
    if [ ! -d "$DEPS_BLD_DIR/$2" ]; then
        mv $DEPS_BLD_DIR/$1 $DEPS_BLD_DIR/$2
    fi
}
move_if *autobahn* autobahn-cpp
move_if openssl* openssl-1.0.2o
move_if *msgpack* msgpack
move_if libwally-core-* libwally-core

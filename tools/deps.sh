#!/usr/bin/env bash
set -e

SHA256SUM_AUTOBAHN=612e0f9fea274ee7a2b3873c7ab86ba82c5ed24a4aa4f125cdeb155c21656dca
SHA256SUM_WEBSOCKETPP=07b3364ad30cda022d91759d4b83ff902e1ebadb796969e58b59caa535a03923
SHA256SUM_MSGPACK=fce702408f0d228a1b9dcab69590d6a94d3938f694b95c9e5e6249617e98d83f
SHA256SUM_WALLYCORE=12b3648742dfc79b1c594ebac6b11e9284382385bf99489a53084bcb719de356
SHA256SUM_BOOST=0445c22a5ef3bd69f5dfb48354978421a85ab395254a26b1ffb0aa1bfd63a108
SHA256SUM_OPENSSL=8173c6a6d6ab314e5e81e9cd1e1632f98586a14d7807697fd24155f162292229

SHASUM=sha256sum

if [ "$(uname)" == "Darwin" ]; then
    SHASUM="shasum -a 256"
fi

if [ ! -d "thirdparty" ]; then
  mkdir thirdparty
fi

if [ ! -d "deps_cache" ]; then
  mkdir deps_cache
fi

function prepare_pkg() {
    if [ ! -d "thirdparty/$1" ]; then
        if [ ! -f "deps_cache/$1_$3.tar.gz" ]; then
            wget -q -O deps_cache/$1_$3.tar.gz $2
        fi
        echo "$3  deps_cache/$1_$3.tar.gz" | $SHASUM --check
        tar -zxf deps_cache/$1_$3.tar.gz -C ./thirdparty/
    fi
}

prepare_pkg autobahn-cpp https://github.com/crossbario/autobahn-cpp/archive/e2d4c8186bc6f3c81f1638b07ad68fcc250c4dfb.tar.gz ${SHA256SUM_AUTOBAHN}
prepare_pkg websocketpp-0.7.0 https://github.com/zaphoyd/websocketpp/archive/0.7.0.tar.gz ${SHA256SUM_WEBSOCKETPP}
prepare_pkg msgpack-2.1.1 https://github.com/msgpack/msgpack-c/releases/download/cpp-2.1.1/msgpack-2.1.1.tar.gz ${SHA256SUM_MSGPACK}
prepare_pkg boost_1_64_0 https://dl.bintray.com/boostorg/release/1.64.0/source/boost_1_64_0.tar.gz ${SHA256SUM_BOOST}
prepare_pkg openssl-1.0.2k https://github.com/openssl/openssl/archive/OpenSSL_1_0_2k.tar.gz ${SHA256SUM_OPENSSL}
prepare_pkg wallycore https://github.com/jgriffiths/libwally-core/archive/08caa2c924a796f0ed53e3d4332889d4808acd33.tar.gz ${SHA256SUM_WALLYCORE}

mv thirdparty/*autobahn* thirdparty/autobahn-cpp
mv thirdparty/openssl* thirdparty/openssl-1.0.2k
mv thirdparty/libwally-core-08caa2c924a796f0ed53e3d4332889d4808acd33 thirdparty/wallycore

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

if [ ! -d "thirdparty/autobahn-cpp" ]; then
    wget -q -O autobahn-cpp.tar.gz https://github.com/crossbario/autobahn-cpp/archive/e2d4c8186bc6f3c81f1638b07ad68fcc250c4dfb.tar.gz
    echo "${SHA256SUM_AUTOBAHN}  autobahn-cpp.tar.gz" | $SHASUM --check
    tar -zxf autobahn-cpp.tar.gz -C ./thirdparty/
    mv thirdparty/*autobahn* thirdparty/autobahn-cpp
    rm -f autobahn-cpp.tar.gz
fi

if [ ! -d "thirdparty/websocketpp-0.7.0" ]; then
    wget -q -O websocketpp-0.7.0.tar.gz https://github.com/zaphoyd/websocketpp/archive/0.7.0.tar.gz
    echo "${SHA256SUM_WEBSOCKETPP}  websocketpp-0.7.0.tar.gz" | $SHASUM --check
    tar -zxf websocketpp-0.7.0.tar.gz -C ./thirdparty/
    rm -f websocketpp-0.7.0.tar.gz
fi

if [ ! -d "thirdparty/msgpack-2.1.1" ]; then
    wget -q -O msgpack-2.1.1.tar.gz https://github.com/msgpack/msgpack-c/releases/download/cpp-2.1.1/msgpack-2.1.1.tar.gz
    echo "${SHA256SUM_MSGPACK}  msgpack-2.1.1.tar.gz" | $SHASUM --check
    tar -zxf msgpack-2.1.1.tar.gz -C ./thirdparty/
    rm -f msgpack-2.1.1.tar.gz
fi

if [ ! -d "thirdparty/boost_1_64_0" ]; then
    wget -q -O boost-1.64.0.tar.gz https://dl.bintray.com/boostorg/release/1.64.0/source/boost_1_64_0.tar.gz
    echo "${SHA256SUM_BOOST}  boost-1.64.0.tar.gz" | $SHASUM --check
    tar -zxf boost-1.64.0.tar.gz -C ./thirdparty/
    rm -f boost-1.64.0.tar.gz
fi

if [ ! -d "thirdparty/openssl-1.0.2k" ]; then
    wget -q -O openssl-1.0.2k.tar.gz https://github.com/openssl/openssl/archive/OpenSSL_1_0_2k.tar.gz
    echo "${SHA256SUM_OPENSSL}  openssl-1.0.2k.tar.gz" | $SHASUM --check
    tar -zxf openssl-1.0.2k.tar.gz -C ./thirdparty/
    mv thirdparty/openssl* thirdparty/openssl-1.0.2k
    rm -f openssl-1.0.2k.tar.gz
fi

if [ ! -d "src/wally" ]; then
    wget -q -O wallycore.tar.gz https://github.com/jgriffiths/libwally-core/archive/08caa2c924a796f0ed53e3d4332889d4808acd33.tar.gz
    echo "${SHA256SUM_WALLYCORE}  wallycore.tar.gz" | $SHASUM --check
    tar -zxf wallycore.tar.gz -C ./src/
    mv src/libwally-core-08caa2c924a796f0ed53e3d4332889d4808acd33 src/wally
    rm -f wallycore.tar.gz
fi


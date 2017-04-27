#!/usr/bin/env bash
set -e

SHA256SUM_AUTOBAHN=612e0f9fea274ee7a2b3873c7ab86ba82c5ed24a4aa4f125cdeb155c21656dca
SHA256SUM_WEBSOCKETPP=07b3364ad30cda022d91759d4b83ff902e1ebadb796969e58b59caa535a03923
SHA256SUM_MSGPACK=fce702408f0d228a1b9dcab69590d6a94d3938f694b95c9e5e6249617e98d83f
SHA256SUM_WALLYCORE=fd0afe9cd485fa9f18c28af7f4e3b4e33eebbe075cbaa4b1c5b2ee1eca99718d

if [ ! -d "thirdparty" ]; then
  mkdir thirdparty
fi

if [ ! -d "thirdparty/autobahn-cpp" ]; then
    wget -O autobahn-cpp.tar.gz https://github.com/crossbario/autobahn-cpp/archive/e2d4c8186bc6f3c81f1638b07ad68fcc250c4dfb.tar.gz && \
    echo "${SHA256SUM_AUTOBAHN} autobahn-cpp.tar.gz" | sha256sum --check && \
    tar -zxvf autobahn-cpp.tar.gz -C ./thirdparty/ && \
    mv thirdparty/*autobahn* thirdparty/autobahn-cpp && \
    rm -f autobahn-cpp.tar.gz
fi

if [ ! -d "thirdparty/websocketpp-0.7.0" ]; then
    wget -O websocketpp-0.7.0.tar.gz https://github.com/zaphoyd/websocketpp/archive/0.7.0.tar.gz && \
    echo "${SHA256SUM_WEBSOCKETPP} websocketpp-0.7.0.tar.gz" | sha256sum --check && \
    tar -zxvf websocketpp-0.7.0.tar.gz -C ./thirdparty/ && \
    rm -f websocketpp-0.7.0.tar.gz
fi

if [ ! -d "thirdparty/msgpack-2.1.1" ]; then
    wget -O msgpack-2.1.1.tar.gz https://github.com/msgpack/msgpack-c/releases/download/cpp-2.1.1/msgpack-2.1.1.tar.gz && \
    echo "${SHA256SUM_MSGPACK} msgpack-2.1.1.tar.gz" | sha256sum --check && \
    tar -zxvf msgpack-2.1.1.tar.gz -C ./thirdparty/ && \
    rm -f msgpack-2.1.1.tar.gz
fi

if [ ! -d "src/wally" ]; then
    wget -O wallycore.tar.gz https://github.com/jgriffiths/libwally-core/archive/1846685f4c4a42109f180d273ec7230880531dca.tar.gz
    echo "${SHA256SUM_WALLYCORE} wallycore.tar.gz" | sha256sum --check && \
    tar -zxvf wallycore.tar.gz -C ./src/ && \
    mv src/libwally-core-1846685f4c4a42109f180d273ec7230880531dca src/wally && \
    rm -f wallycore.tar.gz
fi


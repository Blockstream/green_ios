#/usr/bin/env bash
set -e

if [ \! -e sdk ]; then
  git clone --depth 1 git@gl.blockstream.io:greenaddress/sdk.git
fi

if [ \! -e Pods ]; then
  pod install
fi

cd sdk
./tools/build.sh --iphonesim static
cd ..


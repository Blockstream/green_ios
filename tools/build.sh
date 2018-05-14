#/usr/bin/env bash
set -e

if [ \! -e sdk ]; then
  git clone git@gl.blockstream.io:greenaddress/gdk.git
fi

if [ \! -e Pods ]; then
  pod install
fi

cd sdk
./tools/build.sh --iphonesim static
cd ..


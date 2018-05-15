#/usr/bin/env bash
set -e

if [ \! -e gdk ]; then
  git clone git@gl.blockstream.io:greenaddress/gdk.git
fi

if [ \! -e Pods ]; then
  pod install
fi

cd gdk
./tools/build.sh --iphonesim static
cd ..

xcodebuild -sdk iphonesimulator11.3 -workspace gaios.xcworkspace -scheme gaios

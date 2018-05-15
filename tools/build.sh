#/usr/bin/env bash
set -e

#git fetch gdk master
#git subtree pull --prefix gdk gdk master

if [ \! -e Pods ]; then
  pod install
fi

cd gdk
./tools/build.sh --iphonesim static
cd ..

xcodebuild -sdk $(xcodebuild -showsdks | grep iphonesimulator | tr -s ' ' | cut -d ' ' -f 6-) -workspace gaios.xcworkspace -scheme gaios

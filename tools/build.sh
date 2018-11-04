#/usr/bin/env bash
set -e

if [ ! -d gdk ]; then
    git clone git@gl.blockstream.io:greenaddress/gdk.git
fi

if [ ! -d Pods ]; then
    pod install
fi

GETOPT='/usr/local/opt/gnu-getopt/bin/getopt'

if (($# < 1)); then
    echo 'Usage: build.sh --iphone/--iphonesim.'
    exit 1
fi

TEMPOPT=`"$GETOPT" -n "build.sh" -o s,d -l iphone,iphonesim -- "$@"`
eval set -- "$TEMPOPT"
while true; do
    case $1 in
        --iphone) SDK=iphone; shift ;;
        --iphonesim) SDK=iphonesim; shift ;;
        -- ) break ;;
    esac
done

if [ -d gdk ]; then
    cd gdk
    ./tools/build.sh $@
    cd ..
fi

xcodebuild -sdk $(xcodebuild -showsdks | grep $SDK | tr -s ' ' | cut -d ' ' -f 6-) -workspace gaios.xcworkspace -scheme gaios

# Green - A native GreenAddress wallet for Android


## Clone the repo

```
git clone https://github.com/Blockstream/green_ios.git
cd green_ios
```

## Build requirements

### Global requirements

Get the command line builds tools, or ensure they are up to date

`xcode-select --install`

On macOS 10.14 Mojave, you have to run another step after installing the command line tools:

`installer -pkg /Library/Developer/CommandLineTools/Packages/macOS_SDK_headers_for_macOS_10.14.pkg -target /`

### Local requirements

Install CocoaPods dependencies locally

`pod install`

## Build GDK for Mac OSX

Get sources from GDK repository
```
git clone https://github.com/greenaddress/gdk.git
cd gdk
```

Build GDK dependencies for Mac OSX (virtualenv could be optional if you already have python3 as default)
```
brew update && brew install ninja automake autoconf libtool gnu-sed python3 wget pkg-config swig gnu-getopt gnu-tar
pip3 install virtualenv
virtualenv -p python3 ./venv
source ./venv/bin/activate
pip install --user meson
```

Build for physical device
```
./tools/build.sh --iphone static
```

Build for IPhone simulator
```
./tools/build.sh --iphonesim static
```

Deactivate virtualenv
```
deactivate
cd ..
```

## Mandatory Default Settings

XCode Version 10.1 (10B61) with the following settings:

- Device id `retina4_0`: in Storyboard "View as: IPhone SE"
- Tools version `14460.31`
- IBCocoaTouchPlugin version `14460.20`


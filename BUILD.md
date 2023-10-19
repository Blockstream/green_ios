# Build Blockstream Green for iOS

## Build requirements

Install Xcode.

Get the command line tools with: (ensure to use "Software Update" to install updates)

`sudo xcode-select --install`


Make sure `xcode-select --print-path` returns `/Applications/Xcode.app/Contents/Developer` . Otherwise run:


`sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`


On macOS 10.14 Mojave, you need an additional step after installing the command line tools:


`sudo installer -pkg /Library/Developer/CommandLineTools/Packages/macOS_SDK_headers_for_macOS_10.14.pkg -target /`


## Clone the repo

```
git clone https://github.com/Blockstream/green_ios.git
cd green_ios
```

## How to build


#### Use the released native library (recommended):

Fetch the latest released gdk binaries (our cross-platform wallet library) with the following command:

`./tools/fetch_gdk_binaries.sh`

You can also cross compile it from source.

Use fastlane to build in prodution environment

`fastlane build_signed_prod_release`

#### Install the app

Open the project with Xcode and hit Play.




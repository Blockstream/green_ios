# GreenAddress C/C++ SDK

## Meson/Ninja build:

### Deps:

For Debian Stretch:

* sudo apt-get update && sudo apt-get install build-essential python3-pip ninja-build clang wget autoconf pkg-config libtool swig (optional)
* sudo pip3 install -r tools/requirements.txt or pip3 install --user -r tools/requirements.txt

For Mac OSX:

Install Xcode and brew if not installed, then

* brew update && brew install ninja automake autoconf libtool gnu-sed python3 wget pkg-config swig (optional) gnu-getopt (if on osx)
* pip3 install --user meson
* xcode-select --install

You may also need to change your PATH environment variable to add $HOME/Library/Python/3.6/bin

If you want to target Android you will need to download the NDK and set the ANDROID_NDK env variable to the directory you uncompress it to, for example

* export ANDROID_NDK=$HOME/Downloads/ndk

or you can add it to your bash profile ~/.bash_profile

JAVA bindings can be built by installing swig as explained above and setting JAVA_HOME to the location of the JDK.

### To build:

* tools/build.sh

With no options it will attempt to build all configurations buildable (i.e. for iphone you can only build on osx)

Different options if you want to build a different configuration (flags in squared brackets are optional):

--clang
--gcc
--ndk [armeabi armeabi-v7a arm64-v8a mips mips64 x86 x86_64]
--iphone [static]
--buildtype=debug

for example

* tools/build.sh --gcc

Build output is placed in 'build-<target>', e.g. 'build-clang', 'build-gcc' sub-directories.

You can quickly run a single targets build from the 'build-<target>' sub-directory using:

* ninja

### To clean:

* tools/clean.sh

### To run tests:

#### Using testnet as backend:

From the 'build-<target>' sub-directory:

* ninja test

#### Using local backend (GreenAddress developers only):

* meson test --no-rebuild --print-errorlogs --test-args '\-l'

### Docker based deps & build

This doesn't require any of the previous steps but requires docker installed; it will build the project

* docker build -t greenaddress_sdk - < tools/Dockerfile
* docker run -v $PWD:/sdk greenaddress_sdk

or if you don't want to build it locally

* docker pull greenaddress/ci@sha256:d9f628bdfad8159aafd38139f6de91fa1040f3378ccb813893888dde5d80d13f
* docker run -v $PWD:/sdk greenaddress/ci

in both cases (built or fetched) this will build the sdk with clang by default

if you want to change it for example to ndk armeabi-v7a:

* docker run -v $PWD:/sdk greenaddress/ci bash -c "cd /sdk && ./tools/build.sh --ndk armeabi-v7a"


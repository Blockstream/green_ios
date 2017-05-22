# GreenAddress C/C++ SDK

## Experimental ninja build:

### Deps:

* sudo apt-get install build-essential meson ninja-build clang wget autoconf pkg-config

### To build:

* tools/build.sh

### To clean:

* tools/clean.sh

### To run tests:

#### Using testnet as backend:

* ninja test

#### Using local backend:

* mesontest --test-args l

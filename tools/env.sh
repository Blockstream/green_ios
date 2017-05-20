export CFLAGS="$SDK_CFLAG --sysroot=${MESON_BUILD_ROOT}/toolchain/sysroot -O3"
export LDFLAGS="$SDK_LDFLAGS --sysroot=${MESON_BUILD_ROOT}/toolchain/sysroot"
export CPPFLAGS="$SDK_CFLAGS"
export SYSROOT="${MESON_BUILD_ROOT}/toolchain/sysroot"
export CC=clang
export CXX=clang++

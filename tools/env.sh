export CFLAGS="-march=armv7-a -mfloat-abi=softfp -mfpu=neon -mthumb --sysroot=${MESON_BUILD_ROOT}/toolchain/sysroot -O3"
export LDFLAGS="-Wl,--fix-cortex-a8 --sysroot=${MESON_BUILD_ROOT}/toolchain/sysroot"
export CPPFLAGS="$CFLAGS"
export SYSROOT="${MESON_BUILD_ROOT}/toolchain/sysroot"
export CC=clang
export CXX=clang++

#!/usr/bin/env bash
set -e

echo "[binaries]"
echo "c = '$1/toolchain/bin/clang'"
echo "cpp = '$1/toolchain/bin/clang++'"
echo "ar = '$1/toolchain/bin/$SDK_PLATFORM-ar'"
echo "pkgconfig = 'pkg-config'"
echo "strip = '$1/toolchain/bin/$SDK_PLATFORM-strip'"
echo
echo "[properties]"
echo "root = '$1/toolchain/$SDK_PLATFORM'"

echo "has_function_printf = true"
echo "has_function_hfkerhisadf = false"

echo -n "c_args = ['--sysroot=$1/toolchain/sysroot'"
for a in $SDK_CFLAGS; do
    echo -n ", '$a'"
done
echo "]"
echo -n "cpp_args = ['--sysroot=$1/toolchain/sysroot'"
for a in $SDK_CFLAGS; do
    echo -n ", '$a'"
done
echo "]"
echo -n "c_link_args = ['--sysroot=$1/toolchain/sysroot'"
for a in $SDK_LDFLAGS; do
    echo -n ", '$a'"
done
echo "]"
echo -n "cpp_link_args = ['--sysroot=$1/toolchain/sysroot'"
for a in $SDK_LDFLAGS; do
    echo -n ", '$a'"
done
echo "]"

echo

echo "[host_machine]"
echo "system = 'linux'"
if [ $SDK_ARCH = 'x86' ] ; then
    echo "cpu_family = 'android-$SDK_ARCH'"
    echo "cpu = 'android-$SDK_ARCH'"
else
    echo "cpu_family = '$SDK_ARCH'"
    echo "cpu = '$SDK_ARCH'"
fi
#echo "cpu = '$SDK_CPU'"
echo "endian = 'little'"


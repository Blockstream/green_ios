#!/usr/bin/env bash
set -e

echo "[binaries]"
echo "c = '$1/toolchain/bin/clang'"
echo "cpp = '$1/toolchain/bin/clang++'"
echo "ar = '$1/toolchain/bin/arm-linux-androideabi-ar'"
echo "pkgconfig = 'pkg-config'"
echo "strip = 'strip'"
echo "[properties]"
echo "root = '$1/toolchain/arm-linux-androideabi'"

echo "has_function_printf = true"
echo "has_function_hfkerhisadf = false"

echo "c_args = ['--sysroot=$1/toolchain/sysroot']"
echo "cpp_args = ['--sysroot=$1/toolchain/sysroot']"
echo "c_link_args = ['--sysroot=$1/toolchain/sysroot']"
echo "cpp_link_args = ['--sysroot=$1/toolchain/sysroot']"

echo "[host_machine]"
echo "system = 'linux'"
echo "cpu_family = 'arm'"
echo "cpu = 'armv7'"
echo "endian = 'little'"


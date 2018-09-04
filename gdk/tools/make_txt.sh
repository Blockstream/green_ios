#!/usr/bin/env bash
set -e

function comma_separate() {
    echo "`python -c "import sys; print('[' + ','.join(map(lambda x: '\'' + x + '\'', sys.argv[1:])) + ']')" $@`"
}

if [ \( "$3" = "android" \) ]; then
    C_COMPILER="$1/toolchain/bin/clang"
    CXX_COMPILER="$1/toolchain/bin/clang++"
    STRIP="$1/toolchain/bin/$SDK_PLATFORM-strip"
    CFLAGS=$(comma_separate "--sysroot=$1/toolchain/sysroot" $SDK_CFLAGS)
    LDFLAGS=$(comma_separate $SDK_LDFLAGS)
    ARCHS="''"
elif [ \( "$3" = "iphone" \) -o \( "$3" = "iphonesim" \) ]; then
    C_COMPILER="clang"
    CXX_COMPILER="clang++"
    CFLAGS=$(comma_separate "-isysroot $IOS_SDK_PATH" "-stdlib=libc++" $SDK_CFLAGS_NO_ARCH)
    LDFLAGS=$(comma_separate "-isysroot $IOS_SDK_PATH" "-stdlib=libc++" $SDK_LDFLAGS)
    ARCHS=$(comma_separate $ARCHS)
elif [ \( "$3" = "windows" \) ]; then
    C_COMPILER="x86_64-w64-mingw32-gcc-posix"
    CXX_COMPILER="x86_64-w64-mingw32-g++-posix"
    STRIP="x86_64-w64-mingw32-strip"
else
    echo "cross build type not supported" && exit 1
fi

if [ \( "$3" = "windows" \) ]; then
cat > $2 << EOF

[binaries]
c = '$C_COMPILER'
cpp = '$CXX_COMPILER'
ar = '$AR'
pkgconfig = 'pkg-config'
strip = '$STRIP'

[properties]
target_os = '$4'
archs = '-pipe'

[host_machine]
system = 'linux'
cpu_family = 'x86_64'
cpu = 'i686'
endian = 'little'
EOF
else
cat > $2 << EOF

[binaries]
c = '$C_COMPILER'
cpp = '$CXX_COMPILER'
ar = '$AR'
pkgconfig = 'pkg-config'
strip = '$STRIP'

[properties]
target_os = '$4'
archs = $ARCHS
c_args = $CFLAGS
cpp_args = $CFLAGS
c_link_args = $LDFLAGS
cpp_link_args = $LDFLAGS

[host_machine]
system = 'linux'
cpu_family = '$3-$SDK_ARCH'
cpu = '$3-$SDK_ARCH'
endian = 'little'
EOF
fi

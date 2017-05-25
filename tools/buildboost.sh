#! /usr/bin/env bash
set -e
boost_src_home="${MESON_BUILD_ROOT}/boost_1_64_0"
boost_bld_home="${MESON_BUILD_ROOT}/boost_1_64_0/build"
cd $boost_src_home
cp "${MESON_SOURCE_ROOT}/tools/clang.jam" "$boost_src_home/tools/build/src/tools"
if [ \( "$1" = "--ndk" \) ]; then
    export TARGET_OS=android
    . ${MESON_SOURCE_ROOT}/tools/env.sh
    rm -fr "$boost_src_home/tools/build/src/user-config.jam"
    echo "using clang : $SDK_ARCH : ${SDK_PLATFORM}-clang++ : --sysroot=$SYSROOT ;" > $boost_src_home/tools/build/src/user-config.jam
    ./bootstrap.sh --prefix="$boost_bld_home" --with-libraries=system,thread
    ./b2 --clean
    ./b2 -j$NUM_JOBS --with-thread --with-system toolset=clang-${SDK_ARCH} target-os=android install
elif [ \( "$1" = "--iphone" \) ]; then
    rm -fr "$boost_src_home/tools/build/src/user-config.jam"
    cat > "$boost_src_home/tools/build/src/user-config.jam" << EOF
using darwin : armv7 :
${XCODE_DEFAULT_PATH}/clang++
:
<root>${IPHONE_SDK_PATH}
<compileflags>-std=c++14
<compileflags>"-arch armv7"
<compileflags>"-miphoneos-version-min=9.0"
<compileflags>"-isysroot ${IPHONE_SDK_PATH}"
<linkflags>"-miphoneos-version-min=9.0"
<linkflags>"-isysroot ${IPHONE_SDK_PATH}"
<architecture>arm
<target-os>iphone
;
EOF
    ./bootstrap.sh --prefix="$boost_bld_home" --with-libraries=system,thread
    ./b2 --clean
    ./b2 -j$NUM_JOBS --with-thread --with-system toolset=darwin-armv7 architecture=arm instruction-set=armv7 target-os=iphone link=static install
else
    ./bootstrap.sh --prefix="$boost_bld_home" --with-libraries=system,thread
    ./b2 --clean
    ./b2 -j$NUM_JOBS --with-thread --with-system install
fi

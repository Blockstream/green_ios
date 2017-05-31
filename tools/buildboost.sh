#! /usr/bin/env bash
set -e
boost_src_home="${MESON_BUILD_ROOT}/boost_1_64_0"
boost_bld_home="${MESON_BUILD_ROOT}/boost_1_64_0/build"
cd $boost_src_home
if [ \( "$1" = "--ndk" \) ]; then
    cp "${MESON_SOURCE_ROOT}/tools/darwin.jam" "$boost_src_home/tools/build/src/tools"
    export TARGET_OS=android
    . ${MESON_SOURCE_ROOT}/tools/env.sh
    rm -fr "$boost_src_home/tools/build/src/user-config.jam"
    cat > $boost_src_home/tools/build/src/user-config.jam << EOF
using darwin : $SDK_ARCH :
${SDK_PLATFORM}-clang++
:
<compileflags>-std=c++14
<compileflags>"${SDK_CPPFLAGS}"
<compileflags>"--sysroot=${SYSROOT}"
<archiver>$AR
<linkflags>"--sysroot=${SYSROOT}"
<architecture>${SDK_ARCH}
<target-os>android
;
EOF
    ./bootstrap.sh --prefix="$boost_bld_home" --with-libraries=system,thread
    ./b2 --clean
    ./b2 -j$NUM_JOBS --with-thread --with-system cxxflags=-fPIC toolset=darwin-${SDK_ARCH} target-os=android link=static install
    if [ "$(uname)" == "Darwin" ]; then
       ${RANLIB} $boost_bld_home/lib/libboost_thread.a
       ${RANLIB} $boost_bld_home/lib/libboost_system.a
    fi
elif [ \( "$1" = "--iphone" \) -o \( "$1" = "--iphonesim" \) ]; then
    rm -fr "$boost_src_home/tools/build/src/user-config.jam"
    cat > "$boost_src_home/tools/build/src/user-config.jam" << EOF
using darwin : arm :
${XCODE_DEFAULT_PATH}/clang++
:
<root>${IOS_SDK_PATH}
<compileflags>-std=c++14
<compileflags>"${SDK_CFLAGS}"
<compileflags>"-miphoneos-version-min=9.0"
<compileflags>"-isysroot ${IOS_SDK_PATH}"
<linkflags>"-miphoneos-version-min=9.0"
<linkflags>"-isysroot ${IOS_SDK_PATH}"
<target-os>iphone
;
EOF
    ./bootstrap.sh --prefix="$boost_bld_home" --with-libraries=system,thread
    ./b2 --clean
    ./b2 -j$NUM_JOBS --with-thread --with-system toolset=darwin-arm target-os=iphone link=static install
else
    ./bootstrap.sh --prefix="$boost_bld_home" --with-libraries=system,thread
    ./b2 --clean
    ./b2 -j$NUM_JOBS --with-thread --with-system cxxflags=-fPIC link=static install
fi

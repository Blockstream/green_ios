#! /usr/bin/env bash
set -e

BOOST_NAME="boost_1_66_0"

if [ "x${NUM_JOBS}" == "x" ]; then
    NUM_JOBS=4
fi

cp -r "${MESON_SOURCE_ROOT}/subprojects/${BOOST_NAME}" "${MESON_BUILD_ROOT}/boost"
boost_src_home="${MESON_BUILD_ROOT}/boost"
boost_bld_home="${MESON_BUILD_ROOT}/boost/build"
cd $boost_src_home
if [ \( "$1" = "--ndk" \) ]; then
    cp "${MESON_SOURCE_ROOT}/tools/darwin.jam" "$boost_src_home/tools/build/src/tools"
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
    ./bootstrap.sh --prefix="$boost_bld_home" --with-libraries=chrono,system,thread
    ./b2 --clean
    ./b2 -j$NUM_JOBS --with-chrono --with-thread --with-system cxxflags=-fPIC toolset=darwin-${SDK_ARCH} target-os=android link=static install
    if [ "$(uname)" == "Darwin" ]; then
       ${RANLIB} $boost_bld_home/lib/libboost_chrono.a
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
<compileflags>-fembed-bitcode
<compileflags>"${SDK_CFLAGS}"
<compileflags>"-miphoneos-version-min=9.0"
<compileflags>"-isysroot ${IOS_SDK_PATH}"
<linkflags>"-miphoneos-version-min=9.0"
<linkflags>"-isysroot ${IOS_SDK_PATH}"
<target-os>iphone
;
EOF
    ./bootstrap.sh --prefix="$boost_bld_home" --with-libraries=chrono,system,thread
    ./b2 --clean
    ./b2 -j$NUM_JOBS --with-chrono --with-thread --with-system toolset=darwin-arm target-os=iphone link=static install
else
    test_path ()
    {
        if `command -v command 1>/dev/null 2>/dev/null`; then
            command -v $1 1>/dev/null 2>/dev/null
        else
            hash $1 1>/dev/null 2>/dev/null
        fi
    }

    if test_path gcc; then
      echo "PATH WORKED"
    fi
    ./bootstrap.sh --prefix="$boost_bld_home" --with-libraries=chrono,system,thread
    ./b2 --clean
    ./b2 -j$NUM_JOBS --with-chrono --with-thread --with-system cxxflags="-DPIC -fPIC" link=static install
fi

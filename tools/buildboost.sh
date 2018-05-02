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

# Check that the OS name, as returned by "uname", is as given.
test_uname ()
{
    if test_path uname; then
        test `uname` = $*
    fi
}

# Try and guess the toolset to bootstrap the build with...
Guess_Toolset ()
{
    if test_uname Darwin ; then BOOST_JAM_TOOLSET=darwin
    elif test_uname IRIX ; then BOOST_JAM_TOOLSET=mipspro
    elif test_uname IRIX64 ; then BOOST_JAM_TOOLSET=mipspro
    elif test_uname OSF1 ; then BOOST_JAM_TOOLSET=tru64cxx
    elif test_uname QNX && test_path qcc ; then BOOST_JAM_TOOLSET=qcc
    elif test_uname Linux && test_path xlc; then 
       if /usr/bin/lscpu | grep Byte | grep Little > /dev/null 2>&1 ; then
          # Little endian linux          
          BOOST_JAM_TOOLSET=xlcpp
       else
          #Big endian linux
          BOOST_JAM_TOOLSET=vacpp
       fi
    elif test_uname AIX && test_path xlc; then BOOST_JAM_TOOLSET=vacpp    
    elif test_uname FreeBSD && test_path freebsd-version && test_path clang; then BOOST_JAM_TOOLSET=clang
    elif test_path gcc ; then BOOST_JAM_TOOLSET=gcc
    elif test_path icc ; then BOOST_JAM_TOOLSET=intel-linux
    elif test -r /opt/intel/cc/9.0/bin/iccvars.sh ; then
        BOOST_JAM_TOOLSET=intel-linux
        BOOST_JAM_TOOLSET_ROOT=/opt/intel/cc/9.0
    elif test -r /opt/intel_cc_80/bin/iccvars.sh ; then
        BOOST_JAM_TOOLSET=intel-linux
        BOOST_JAM_TOOLSET_ROOT=/opt/intel_cc_80
    elif test -r /opt/intel/compiler70/ia32/bin/iccvars.sh ; then
        BOOST_JAM_TOOLSET=intel-linux
        BOOST_JAM_TOOLSET_ROOT=/opt/intel/compiler70/ia32/
    elif test -r /opt/intel/compiler60/ia32/bin/iccvars.sh ; then
        BOOST_JAM_TOOLSET=intel-linux
        BOOST_JAM_TOOLSET_ROOT=/opt/intel/compiler60/ia32/
    elif test -r /opt/intel/compiler50/ia32/bin/iccvars.sh ; then
        BOOST_JAM_TOOLSET=intel-linux
        BOOST_JAM_TOOLSET_ROOT=/opt/intel/compiler50/ia32/
    elif test_path pgcc ; then BOOST_JAM_TOOLSET=pgi
    elif test_path pathcc ; then BOOST_JAM_TOOLSET=pathscale
    elif test_path como ; then BOOST_JAM_TOOLSET=como
    elif test_path KCC ; then BOOST_JAM_TOOLSET=kcc
    elif test_path bc++ ; then BOOST_JAM_TOOLSET=kylix
    elif test_path aCC ; then BOOST_JAM_TOOLSET=acc
    elif test_uname HP-UX ; then BOOST_JAM_TOOLSET=acc
    elif test -r /opt/SUNWspro/bin/cc ; then
        BOOST_JAM_TOOLSET=sunpro
        BOOST_JAM_TOOLSET_ROOT=/opt/SUNWspro/
    # Test for "cc" as the default fallback.
    elif test_path $CC ; then BOOST_JAM_TOOLSET=cc
    elif test_path cc ; then
        BOOST_JAM_TOOLSET=cc
        CC=cc
    fi
    if test "$BOOST_JAM_TOOLSET" = "" ; then
        error_exit "Could not find a suitable toolset."
    fi
}

    Guess_Toolset
    echo "TOOLSET $BOOST_JAM_TOOLSET"

    ./bootstrap.sh --prefix="$boost_bld_home" --with-libraries=chrono,system,thread --guess-toolset
    ./b2 --clean
    ./b2 -j$NUM_JOBS --with-chrono --with-thread --with-system cxxflags="-DPIC -fPIC" link=static install
fi

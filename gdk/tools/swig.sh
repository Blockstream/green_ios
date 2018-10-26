#!/bin/bash
set -e

sed_exe=$1

result="$3/com/blockstream/libgreenaddress/GASDK.java"

mkdir -p `dirname $result`

swig -java -noproxy -package com.blockstream.libgreenaddress -o $2 -outdir $3 $4

$sed_exe -i 's/GASDKJNI/GASDK/g' $2

# Merge the constants and JNI interface into GASDK.java
grep -v '^}$' $3/GASDKJNI.java | $sed_exe 's/GASDKJNI/GASDK/g' >$result
grep 'public final static' $3/GASDKConstants.java >>$result
cat $5 >>$result
echo '}' >>$result

JAVAC_SOURCE=$7
JAVAC_TARGET=$7
JAVAC_ARGS="-implicit:none -source $JAVAC_SOURCE -target $JAVAC_TARGET -sourcepath $3/com/blockstream/libgreenaddress/ $3/com/blockstream/libgreenaddress/GASDK.java"
if [ $JAVAC_TARGET = "1.7" ] ; then
    JAVAC_ARGS="$JAVAC_ARGS -bootclasspath $JAVA_HOME/jre/lib/rt.jar"
fi

$JAVA_HOME/bin/javac $JAVAC_ARGS

tmp_wally_java_dir=`mktemp -d`
pushd . > /dev/null
cd $tmp_wally_java_dir
$JAVA_HOME/bin/jar xf $6
popd > /dev/null

$JAVA_HOME/bin/jar cf $3/GASDK.jar -C $3 'com/blockstream/libgreenaddress/GASDK$Obj.class' \
  -C $3 'com/blockstream/libgreenaddress/GASDK$NotificationHandler.class' \
  -C $3 'com/blockstream/libgreenaddress/GASDK$JSONConverter.class' \
  -C $3 'com/blockstream/libgreenaddress/GASDK.class' \
  -C $tmp_wally_java_dir .

# Clean up
rm -f $3/*.java
rm -rf $tmp_wally_java_dir

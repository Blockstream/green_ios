#!/bin/sh

sed_exe=$1

result="$3/com/blockstream/libgreenaddress/GASDK.java"

mkdir -p `dirname $result`

swig -java -noproxy -package com.blockstream.libgreenaddress -o $2 -outdir $3 $4

$sed_exe -i 's/GASDKJNI/GASDK/g' $2

# Merge the constants and JNI interface into GASDK.java
grep -v '^}$' $3/GASDKJNI.java | $sed_exe 's/GASDKJNI/GASDK/g' >$result
grep 'public final static' $3/GASDKConstants.java >>$result
echo '}' >>$result

$JAVA_HOME/bin/javac -sourcepath $3/com/blockstream/libgreenaddress/ $3/com/blockstream/libgreenaddress/GASDK.java
$JAVA_HOME/bin/jar cf $3/GASDK.jar -C $3 'com/blockstream/libgreenaddress/GASDK$Obj.class' -C $3 'com/blockstream/libgreenaddress/GASDK.class'

# Clean up
rm -f $3/*.java

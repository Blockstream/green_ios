#!/usr/bin/env bash
set -e

DEP_NAME=""
SHA_SUM=""
UNTAR_NAME=""
WRAP_NAME=""
URL=""

GETOPT='getopt'
if [ "$(uname)" == "Darwin" ]; then
    GETOPT='/usr/local/opt/gnu-getopt/bin/getopt'
fi

TEMPOPT=`"$GETOPT" -n "'upgrade_deps.sh" -o l:,s:,u: -- "$@"`
eval set -- "$TEMPOPT"
while true; do
    case "$1" in
        -l ) DEP_NAME="$2-meson"; UNTAR_NAME="$2"; WRAP_NAME="$2"; shift 2 ;;
        -s ) SHA_SUM="$2"; shift 2 ;;
        -u ) URL="$2"; shift 2 ;;
        -- ) shift; break ;;
    esac
done

if [ "x${DEP_NAME}" == "xwallycore-meson" ]; then
    UNTAR_NAME="libwally-core"
fi

TOOLS_DIR=${PWD}/tools
WRAP_DIR=${PWD}/subprojects
DEP_DIR=${WRAP_DIR}/${DEP_NAME}
TMP=$(mktemp -d)

pushd . >& /dev/null

cd ${TMP}

echo "Extracting old meson build..."
tar zxvf ${DEP_DIR}/${DEP_NAME}.tar.gz >& /dev/null
echo "Recreating meson build..."
mv ${UNTAR_NAME}* ${UNTAR_NAME}-${SHA_SUM}
echo "Generating meson build patch..."
tar zcvf ${DEP_DIR}/${DEP_NAME}.tar.gz ${UNTAR_NAME}-${SHA_SUM} >& /dev/null

echo "Updating wrap definitions..."
PATCH_SHA256=$(sha256sum ${DEP_DIR}/${DEP_NAME}.tar.gz | cut -f 1 -d ' ')
if [ "x${URL}" != "x" ]; then
    wget -O tmp.tar.gz ${URL}
    SOURCE_SHA256=$(sha256sum tmp.tar.gz | cut -f 1 -d ' ')
    sed -i -e "s!\(source_url.*=\).*!\1 ${URL}!" ${WRAP_DIR}/${WRAP_NAME}.wrap
    sed -i -e "s!\(source_hash.*=\).*!\1 ${SOURCE_SHA256}!" ${WRAP_DIR}/${WRAP_NAME}.wrap
fi

if [ "x${DEP_NAME}" == "xwallycore-meson" ]; then
    sed -i -e "s!\(${UNTAR_NAME}-\).*!\1${SHA_SUM}\"!" ${TOOLS_DIR}/build${WRAP_NAME}.sh
fi

sed -i -e "s!\(directory.*=\).*!\1 ${UNTAR_NAME}-${SHA_SUM}!" ${WRAP_DIR}/${WRAP_NAME}.wrap
sed -i -e "s!\(source_filename.*=\).*!\1 ${UNTAR_NAME}-${SHA_SUM}.tar.gz!" ${WRAP_DIR}/${WRAP_NAME}.wrap
sed -i -e "s!\(source_url.*archive/\).*!\1${SHA_SUM}.tar.gz!" ${WRAP_DIR}/${WRAP_NAME}.wrap
sed -i -e "s!\(patch_hash.*=\).*!\1 ${PATCH_SHA256}!" ${WRAP_DIR}/${WRAP_NAME}.wrap

popd >& /dev/null
rm -rf ${TMP}

#!/usr/bin/env bash
# Downloads and installs the pre-built gdk libraries for use by green_ios
set -e

# ----- Help
help_message() {
  cat <<- _EOF_
  Downloads and install the pre-built GDK libraries

  Usage: $SCRIPT_NAME [-h|--help] [-c|--commit sha256] [-s|--simulator]

  Options:
    -c, --commit Download the provided commit
    -h, --help  Display this help message and exit

_EOF_
  exit 0
}

# ----- Vars
ARM_NAME="gdk-iphone"
ARM_SIM_NAME="gdk-iphonesim-arm64"
X86_SIM_NAME="gdk-iphonesim-x86_64"

ARM_TARBALL="gdk-iphone.tar.gz"
ARM_SIM_TARBALL="gdk-iphone-sim.tar.gz"
X86_SIM_TARBALL="gdk-iphone-sim-x86_64.tar.gz"
# The version of gdk to fetch and its sha256 checksum for integrity checking
TAGNAME="release_0.71.3"
RELEASES_URL="https://github.com/Blockstream/gdk/releases"
ARM_URL="${RELEASES_URL}/download/${TAGNAME}/${ARM_TARBALL}"
ARM_SIM_URL="${RELEASES_URL}/download/${TAGNAME}/${ARM_SIM_TARBALL}"
X86_SIM_URL="${RELEASES_URL}/download/${TAGNAME}/${X86_SIM_TARBALL}"
ARM_SHA256="8c5be13bd8cbfaba6bb0e8bfb10fda89541010e15bfee062e8ed6ce468fc48b5"
ARM_SIM_SHA256="ca6f71031aba6af807ac12172fc0cd15e7ff4ee3873d77ae46efe1b748f8702c"
X86_SIM_SHA256="42f5f78d2da0667f291ec43e5c1505cd100967eba812958f406ea9547e1f7242"
VALIDATE_CHECKSUM=true
GCLOUD_URL="https://storage.googleapis.com/green-gdk-builds/gdk-"

# --- Argument handling
# https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -h | --help)
      help_message ;;
    -c | --commit)
      COMMIT=${2}
      shift 2;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done
set -- "${POSITIONAL[@]:-}" # restore positional parameters

# Pre-requisites
function check_command() {
    command -v $1 >/dev/null 2>&1 || { echo >&2 "$1 not found, exiting."; exit 1; }
}
check_command curl
check_command gzip
check_command shasum

# Find out where we are being run from to get paths right
if [ ! -d "$(pwd)/gaios" ]; then
    echo "Run fetch script from gaios project root folder"
    exit 1
fi

# Clean up any previous install
rm -rf gdk-iphone
COMMON_MODULE_ROOT=$(pwd)/libgdk
mkdir -p $COMMON_MODULE_ROOT/include


download() {
  IS_SIM=$1
  NAME=$2
  TARBALL=$3
  URL=$4
  SHA256=$5
  PLATFORM=$6
  # Fetch, validate and decompress gdk
  if [[ -n "$COMMIT" ]]; then
    URL="${GCLOUD_URL}${COMMIT}/ios/${TARBALL}"
    VALIDATE_CHECKSUM=false
  fi
  echo "Downloading from $URL"
  curl -sL -o ${TARBALL} "${URL}"
  if [[ $VALIDATE_CHECKSUM = true ]]; then
    echo "Validating checksum $SHA256"
    echo "${SHA256} ${TARBALL}"
    shasum -a 256 ${TARBALL}
    echo "${SHA256}  ${TARBALL}" | shasum -a 256 --check
  fi

  tar xvf ${TARBALL}

  if [[ $IS_SIM = true ]]; then
    mkdir -p $COMMON_MODULE_ROOT/libs/ios_simulator_$PLATFORM
    cp $NAME/lib/iphonesimulator/libgreenaddress_full.a $COMMON_MODULE_ROOT/libs/ios_simulator_$PLATFORM
  else

    # Copy header files
    mkdir -p $COMMON_MODULE_ROOT/include
    cp $NAME/include/gdk/*/*.h $COMMON_MODULE_ROOT/include/
    cp $NAME/include/gdk/*.h $COMMON_MODULE_ROOT/include/
    cp $NAME/include/gdk/module.modulemap $COMMON_MODULE_ROOT/include/
    cp -r $NAME/share $COMMON_MODULE_ROOT/

    mkdir -p $COMMON_MODULE_ROOT/libs/ios_$PLATFORM
    cp $NAME/lib/iphoneos/libgreenaddress_full.a $COMMON_MODULE_ROOT/libs/ios_$PLATFORM
  fi

  # Cleanup
  rm ${TARBALL}
  rm -fr $NAME
}

download false $ARM_NAME $ARM_TARBALL $ARM_URL $ARM_SHA256 "arm64"
download true $ARM_SIM_NAME $ARM_SIM_TARBALL $ARM_SIM_URL $ARM_SIM_SHA256 "arm64"
download true $X86_SIM_NAME $X86_SIM_TARBALL $X86_SIM_URL $X86_SIM_SHA256 "x86"

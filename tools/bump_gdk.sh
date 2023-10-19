#!/usr/bin/env bash
set -e
# Upgrades gdk to latest available at github.com/Blockstream/gdk

function check_command() {
    command -v $1 >/dev/null 2>&1 || { echo >&2 "$1 not found, exiting."; exit 1; }
}

check_command awk
check_command mktemp
check_command grep
check_command sed
check_command curl
check_command jq
check_command shasum

# ----- Help
help_message() {
  cat <<- _EOF_
  Update GDK

  Usage: $SCRIPT_NAME [-h|--help] [-t|--tag]

  Options:
    -h, --help  Display this help message and exit
    -t, --t     Specify tag name

_EOF_
  exit 0
}

# ----- Vars
TAGNAME=false

# --- Argument handling
# https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -h | --help)
      help_message ;;
    -t | --tag)
      TAGNAME=${2}
      shift 2;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done

set -- "${POSITIONAL[@]:-}" # restore positional parameters


# --- Execution
if [[ $TAGNAME = false ]]; then
  TAGNAME=$(curl https://api.github.com/repos/blockstream/gdk/releases/latest | jq -r .tag_name)
fi

# Import Green key
PGPKEY="04BEBF2E35A2AF2FFDF1FA5DE7F054AA2E76E792"
gpg --keyserver pgp.mit.edu --recv-keys $PGPKEY
# Download the key file
curl -sL -o IOS_SHA256SUMS.asc https://github.com/Blockstream/gdk/releases/download/$TAGNAME/IOS_SHA256SUMS.asc
# Check the signed key
gpg --verify IOS_SHA256SUMS.asc
# Inspect the key file
gpg --keyid-format long --list-options show-keyring IOS_SHA256SUMS.asc


update() {
    TARFILE=$1
    PLATFORM=$2
    TARURL="https://github.com/Blockstream/gdk/releases/download/$TAGNAME/$TARFILE"
    curl -sL -o $TARFILE $TARURL
    SHA256_TAR=$(shasum -a256 $TARFILE | awk '{print $1;}')
    SHA256_SUM=$(cat IOS_SHA256SUMS | grep $TARFILE | awk '{print $1;}')
    if [ "$SHA256_TAR" != "$SHA256_SUM" ]; then
        echo "Shasum ${TARFILE} mismatch"
        exit 1
    fi
    sed -i '' -e "s/${PLATFORM}=.*/${PLATFORM}=\"${SHA256_TAR}\"/" ./tools/fetch_gdk_binaries.sh
    rm $TARFILE
}
    
sed -i '' -e "s/TAGNAME=.*/TAGNAME=\"${TAGNAME}\"/" ./tools/fetch_gdk_binaries.sh
update "gdk-iphone.tar.gz" "ARM_SHA256"
update "gdk-iphone-sim.tar.gz" "ARM_SIM_SHA256"
update "gdk-iphone-sim-x86_64.tar.gz" "X86_SIM_SHA256"

git add ./tools/fetch_gdk_binaries.sh
git commit -m "Update GDK to ${TAGNAME}" -S
rm -f IOS_SHA256SUMS.asc IOS_SHA256SUMS

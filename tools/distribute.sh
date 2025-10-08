#!/bin/bash
set -e

# --- Help
help_message() {
  cat <<- _EOF_
  Generate data for adhoc distribution in dest folder

  Usage: $SCRIPT_NAME [-h|--help] -a|--app [-d|--dest] -u|--url

  Options:
    -a, --app Pass ipa app path
    -d, --dest The destination folder (default dist)
    -u, --url Base url to publish
    -h, --help  Display this help message and exit

_EOF_
  exit 0
}

# --- Argument handling
# https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"
case $key in
    -h | --help)
      help_message ;;
    -a | --app)
      APP=${2}
      shift 2;;
    -d | --dest)
      DEST=${2}
      shift 2;;
    -u | --url)
      URL=${2}
      shift 2;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done

set -- "${POSITIONAL[@]:-}" # restore positional parameters

# --- Setup variables
LAST_TAG=$(git describe --abbrev=0 | sed -e "s/^release_//")
BASENAME_IPA=$(basename -- $APP)
NAME_IPA=${BASENAME_IPA%.ipa}
URL_IPA=${URL}/${BASENAME_IPA}
if [ -z ${DEST} ]; then
    DEST="./dist"
fi

# --- Build distribution files
mkdir -p ${DEST}
cp ${APP} ${DEST} | true

cat > "${DEST}/index.html" <<EOL
<html>
<head>
    <title>Blockstream iOS Internal Distribution</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            text-align: center;
            padding: 40px;
            background-color: #f8f9fa;
            color: #333;
        }
        .container {
            max-width: 600px;
            margin: 0 auto;
            background-color: #ffffff;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 4px 8px rgba(0,0,0,0.1);
        }
        .install-button {
            display: inline-block;
            background-color: #007aff;
            color: white;
            padding: 18px 36px;
            text-decoration: none;
            border-radius: 8px;
            font-size: 24px;
            font-weight: bold;
            margin-bottom: 30px;
        }
        .commit-info {
            text-align: center;
            margin-top: 20px;
        }
        .commit-info a {
            color: #007aff;
            text-decoration: none;
        }
        .commit-info a:hover {
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Blockstream iOS Build</h1>
        <a href="itms-services://?action=download-manifest&url=${URL}/manifest.plist" class="install-button">Install App</a>

        <div class="commit-info">
            <p><strong>Branch:</strong> ${CI_COMMIT_REF_NAME}</p>
            <p><strong>Commit:</strong> <a href="https://github.com/Blockstream/green_ios/commit/${CI_COMMIT_SHA}">${CI_COMMIT_SHORT_SHA}</a> - ${CI_COMMIT_TITLE}</p>
        </div>
    </div>
</body>
</html>
EOL

cat > "${DEST}/manifest.plist" <<EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>items</key>
    <array>
        <dict>
            <key>assets</key>
            <array>
                <dict>
                    <key>kind</key>
                    <string>software-package</string>
                    <key>url</key>
                    <string>${URL_IPA}</string>
                </dict>
            </array>
            <key>metadata</key>
            <dict>
                <key>bundle-identifier</key>
                <string>io.blockstream.greendev</string>
                <key>bundle-version</key>
                <string>${LAST_TAG}</string>
                <key>kind</key>
                <string>software</string>
                <key>title</key>
                <string>${NAME_IPA}</string>
            </dict>
        </dict>
    </array>
</dict>
</plist>
EOL

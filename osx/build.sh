#!/bin/bash
# set -ex
# The above is very useful during debugging.
# 
# **************************************************
# Build script for KA-Lite using Packages and virtualenvwrapper.
#
# Environment Variable/s:
# . IS_KALITE_RELEASE == must be set to sign the .app and .pkg packages
#
# Arguments
# . $1 == $KA_LITE_REPO_ZIP == URL of the Github .zip for the KA-Lite branch to use.
#       Example: https://github.com/learningequality/ka-lite/archive/develop.zip
# . $2 == $CONTENTPACKS_EN_URL == URL of the contentpacks/en.zip
#       Example: http://pantry.learningequality.org/downloads/ka-lite/0.16/content/contentpacks/en.zip
#
# Steps
# 1. Check if requirements are installed: packages, wget.
# 2. Check for valid arguments in terminal.
# 3. Create temporary directory `temp`.
# 4. Download the contentpacks/en.zip.
# 5. Download python installer.
# 6. Get Github source, optionally use argument for the Github .zip URL, extract, and rename it to `ka-lite`.
# 7. Install and create virtualenv.
# 8. Upgrade Python Pip
# 9. Run `pip install -r requirements_dev.txt` to install the Makefile executables.
# 10. Installing PEX to create kalite PEX file
# 11. Update KA Lite installer version.
# 12. Run `make dist` for assets and docs.
# 13. Build the Xcode project.
# 14. Code-sign the built .app if running on build server.
# 15. Run Packages script to build the .pkg.
# 16. Build the dmg file.


# REF: Bash References
# . http://www.peterbe.com/plog/set-ex
# . http://stackoverflow.com/questions/3601515/how-to-check-if-a-variable-is-set-in-bash
# . http://stackoverflow.com/questions/4774054/reliable-way-for-a-bash-script-to-get-the-full-path-to-itself/4774063#4774063
# . http://askubuntu.com/questions/385528/how-to-increment-a-variable-in-bash#385532
# . http://stackoverflow.com/questions/592620/check-if-a-program-exists-from-a-bash-script
# . http://stackoverflow.com/questions/2924422/how-do-i-determine-if-a-web-page-exists-with-shell-scripting/20988182#20988182
# . http://stackoverflow.com/questions/2751227/how-to-download-source-in-zip-format-from-github/18222354#18222354
# . http://stackoverflow.com/questions/592620/check-if-a-program-exists-from-a-bash-script
# 
# 
# MUST: test the signed .pkg or .app on a target Mac with:
# . pkgutil --check-signature KA-Lite.pkg -- or;
# . pkgutil --check-signature KA-Lite.app -- or;
# . spctl --assess --type install KA-Lite.pkg

STEP=0
STEPS=16

# TODO(cpauya): get version from `ka-lite/kalite/version.py`
# Set the default value to `develop` as suggested by [@benjaoming](https://github.com/learningequality/ka-lite-installers/pull/433#discussion_r96399812), so we can use the VERSION environment in bamboo settings. 
VERSION=${VERSION:-"develop"}

echo "KA-Lite OS X build script for version '$VERSION' and above."

CONTENT_VERSION="0.17"
PANTRY_CONTENT_URL="http://pantry.learningequality.org/downloads/ka-lite/$CONTENT_VERSION/content"


((STEP++))
echo "$STEP/$STEPS. Checking if requirements are installed..."

PACKAGES_EXEC="packagesbuild"
if ! command -v $PACKAGES_EXEC >/dev/null 2>&1; then
    echo ".. Abort! 'packagesbuild' is not installed."
    exit 1
fi

WGET_EXEC="wget"
if ! command -v $WGET_EXEC >/dev/null 2>&1; then
    echo ".. Abort! 'wget' is not installed."
    exit 1
fi

XCODEBUILD_EXEC="xcodebuild"
if ! command -v $XCODEBUILD_EXEC >/dev/null 2>&1; then
    echo ".. Abort! 'xcodebuild' is not installed."
    exit 1
fi


# REF: http://stackoverflow.com/questions/4774054/reliable-way-for-a-bash-script-to-get-the-full-path-to-itself/4774063#comment15185627_4774063
SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )
TEMP_DIR_NAME="temp"
WORKING_DIR="$SCRIPTPATH/$TEMP_DIR_NAME"
CONTENT_DIR="$WORKING_DIR/content"
CONTENTPACKS_DIR="$CONTENT_DIR/contentpacks"


# Check the arguments
((STEP++))
echo "$STEP/$STEPS. Checking the arguments..."

# MUST: Use the archive link, which defaults to develop branch, so that the folder name
# starts with the repo name like these examples:
#    ka-lite-develop
#    ka-lite-0.14.x.zip
# this will make it easier to "rename" the archive.
# Example: KA_LITE_REPO_ZIP="https://github.com/learningequality/ka-lite/archive/develop.zip"
# KA_LITE_REPO_ZIP="https://github.com/learningequality/ka-lite/archive/develop.zip"
KA_LITE_REPO_ZIP="https://github.com/learningequality/ka-lite/archive/$VERSION.zip"


# Check if an argument was passed as URL for the script and use that instead.
if [ "$1" != "" ]; then
    echo ".. Checking validity of the Github repo zip argument -- $1..."
    if curl --output /dev/null --silent --head --fail "$1"
    then
        # Use the argument as the ka-lite repo zip.
        KA_LITE_REPO_ZIP=$1
    else
        echo ".. Abort!  The '$1' argument is not a valid URL for the Github repo!"
        exit 1
    fi
fi


# Check if an argument was passed as URL for the en.zip and use that instead.
CONTENTPACKS_EN_ZIP="en.zip"
CONTENTPACKS_EN_URL="$PANTRY_CONTENT_URL/contentpacks/$CONTENTPACKS_EN_ZIP"
if [ "$2" != "" ]; then
    echo ".. Checking validity of en.zip argument -- $2..."
    # MUST: Check if valid url!
    if curl --output /dev/null --silent --head --fail "$2"
    then
        # Use the argument as the en.zip url.
        CONTENTPACKS_EN_URL=$2
    else
        echo ".. Abort!  The '$2' argument is not a valid URL for the en.zip!"
        exit 1
    fi
fi
echo ".. OK, arguments are valid."


# Create temporary directory
((STEP++))
echo "$STEP/$STEPS. Checking '$WORKING_DIR' temporary directory..."
if ! [ -d "$WORKING_DIR" ]; then
    echo ".. Creating temporary directory named '$WORKING_DIR'..."
    mkdir "$WORKING_DIR"
fi


# Download the contentpacks/en.zip.
((STEP++))
CONTENTPACKS_DIR="$WORKING_DIR/content/contentpacks"
test ! -d "$CONTENTPACKS_DIR" && mkdir -p "$CONTENTPACKS_DIR"

CONTENTPACKS_EN_PATH="$CONTENTPACKS_DIR/contentpack-$CONTENT_VERSION.en.zip"
echo "$STEP/$STEPS. Checking for en.zip"
if [ -f "$CONTENTPACKS_EN_PATH" ]; then
    echo ".. Found '$CONTENTPACKS_EN_PATH' so will not re-download.  Delete it to re-download."
else
    echo ".. Downloading from '$CONTENTPACKS_EN_URL' to '$CONTENTPACKS_EN_PATH'..."
    wget --retry-connrefused --read-timeout=20 --waitretry=1 -t 100 --continue -O $CONTENTPACKS_EN_PATH $CONTENTPACKS_EN_URL
    if [ $? -ne 0 ]; then
        echo ".. Abort!  Can't download '$CONTENTPACKS_EN_URL'."
        exit 1
    fi
fi

# Create output directory path.
OUTPUT_PATH="$WORKING_DIR/output"
TEMP_OUTPUT_PATH="$WORKING_DIR/temp-output"
test -e "$TEMP_OUTPUT_PATH" && rm -r "$TEMP_OUTPUT_PATH"
test -e "$OUTPUT_PATH" && rm -r "$OUTPUT_PATH"
test ! -d "$OUTPUT_PATH" && mkdir "$OUTPUT_PATH"
test ! -d "$TEMP_OUTPUT_PATH" && mkdir "$TEMP_OUTPUT_PATH"

# Download python installer.
((STEP++))
PYTHON_DOWNLOAD_URL="https://www.python.org/ftp/python/2.7.12/python-2.7.12-macosx10.6.pkg"
cd $TEMP_OUTPUT_PATH
echo "$STEP/$STEPS. Downloading the minimum requirement of Python Installer at $PYTHON_DOWNLOAD_URL ..."
wget --retry-connrefused --read-timeout=20 --waitretry=1 -t 100 --continue $PYTHON_DOWNLOAD_URL
if [ $? -ne 0 ]; then
    echo ".. Abort!  Can't download Python at '$PYTHON_DOWNLOAD_URL'"
    exit 1
fi

KA_LITE_PROJECT_DIR="$SCRIPTPATH/KA-Lite"
DMG_PATH="$OUTPUT_PATH/KA-Lite-Installer.dmg"
DMG_BUILDER_PATH="$WORKING_DIR/create-dmg"
CREATE_DMG="$DMG_BUILDER_PATH/create-dmg"
KA_LITE_ICNS_PATH="$KA_LITE_PROJECT_DIR/KA-Lite/Resources/images/ka-lite.icns"

test ! -d "$OUTPUT_PATH" && mkdir "$OUTPUT_PATH"

((STEP++))
echo "$STEP/$STEPS. Checking create dmg library..."
CREATE_DMG_ZIP="$WORKING_DIR/create-dmg.zip"
CREATE_DMG_URL="https://github.com/mrpau/create-dmg/archive/master.zip"
# clone the .dmg builder if non-existent
if ! [ -d $DMG_BUILDER_PATH ]; then
    cd $WORKING_DIR
    echo ".. Downloading create dmg library at '$CREATE_DMG_URL'..."
    wget --retry-connrefused --read-timeout=20 --waitretry=1 -t 100 --continue -O $CREATE_DMG_ZIP $CREATE_DMG_URL
        # Extract KA-Lite
    echo ".. Extracting '$CREATE_DMG_ZIP'..."
    tar -xf $CREATE_DMG_ZIP -C $WORKING_DIR
    mv $WORKING_DIR/create-dmg-* create-dmg
fi

((STEP++))
echo "$STEP/$STEPS. Checking Github source..."

KA_LITE="ka-lite"
KA_LITE_ZIP="$WORKING_DIR/$KA_LITE.zip"
KA_LITE_DIR="$WORKING_DIR/$KA_LITE"

# Don't download the KA-Lite repo if there's already a `ka-lite` directory.
if [ -d "$KA_LITE_DIR" ]; then
    echo ".. Found ka-lite directory '$KA_LITE_DIR' so will not download and extract zip."
else
    # Get KA-Lite repo
    if [ -e "$KA_LITE_ZIP" ]; then
        echo ".. Found '$KA_LITE_ZIP' file so will not re-download.  Delete this file to re-download."
    else
        # REF: http://stackoverflow.com/a/18222354/84548ƒ®1
        # How to download source in .zip format from GitHub?
        echo ".. Downloading from '$KA_LITE_REPO_ZIP' to '$KA_LITE_ZIP'..."
        wget --retry-connrefused --read-timeout=20 --waitretry=1 -t 100 --continue -O $KA_LITE_ZIP $KA_LITE_REPO_ZIP
        if [ $? -ne 0 ]; then
            echo ".. Abort!  Can't download 'ka-lite' source."
            exit 1
        fi
    fi

    # Extract KA-Lite
    echo ".. Extracting '$KA_LITE_ZIP'..."
    tar -xf $KA_LITE_ZIP -C $WORKING_DIR
    if [ $? -ne 0 ]; then
        echo ".. Abort!  Can't extract '$KA_LITE_ZIP'."
        exit 1
    fi

    # Rename the extracted folder.
    echo ".. Renaming '$WORKING_DIR/$KA_LITE-*' to $KA_LITE_DIR'..."
    mv $WORKING_DIR/$KA_LITE-* $KA_LITE_DIR
    if ! [ -d "$KA_LITE_DIR" ]; then
        echo ".. Abort!  Did not successfully rename '$WORKING_DIR/$KA_LITE-*' to '$KA_LITE_DIR'."
        exit 1
    fi
fi

((STEP++))
echo "$STEP/$STEPS. Install and create virtualenv..."

# Must use Python version 2.7.11+ to build KA Lite. 
PIP_CMD="pip install virtualenv"
cd "$KA_LITE_DIR"
echo ".. Running $PIP_CMD..."
$PIP_CMD

bash $SCRIPTPATH/ka-lite-python-version-check.sh
if [ $? -ne 0 ]; then
    echo ".. Abort! Python 2.7.11+ is required to build KA Lite"
    exit 1
fi

VENV_PATH="$(which virtualenv)"
ENV_CMD="$VENV_PATH venv --python=python2.7"
$ENV_CMD
if [ $? -ne 0 ]; then
    echo ".. Abort!  Error/s encountered running $ENV_CMD"
    exit 1
fi

source venv/bin/activate
ENV_PATH="$(pwd venv)"

((STEP++))
echo "$STEP/$STEPS. Upgrading Python Pip..."

# MUST: Upgrade Python's pip.
UPGRADE_PIP_CMD="pip install --upgrade pip"
$UPGRADE_PIP_CMD
if [ $? -ne 0 ]; then
    echo ".. Abort!  Error/s encountered running '$UPGRADE_PIP_CMD'."
    exit 1
fi

((STEP++))
echo "$STEP/$STEPS. Installing Pip requirements for use of Makefile..."

PIP_CMD="pip install -r requirements_dev.txt"
# TODO(cpauya): Streamline this to pip install only the needed modules/executables for `make dist` below.
cd "$KA_LITE_DIR"
echo ".. Running $PIP_CMD..."
$PIP_CMD
if [ $? -ne 0 ]; then
    echo ".. Abort!  Error/s encountered running '$PIP_CMD'."
    exit 1
fi

PIP_CMD="pip install -r requirements_sphinx.txt"
# TODO(cpauya): Streamline this to pip install only the needed modules/executables for `make dist` below.
cd "$KA_LITE_DIR"
echo ".. Running $PIP_CMD..."
$PIP_CMD
if [ $? -ne 0 ]; then
    echo ".. Abort! Error/s encountered running '$PIP_CMD'."
    exit 1
fi

NPM_CMD="npm install"
cd "$KA_LITE_DIR"
echo ".. Running $NPM_CMD..."
$NPM_CMD
if [ $? -ne 0 ]; then
    echo ".. Abort! Error/s encountered running '$NPM_CMD'."
    exit 1
fi

PIP_CMD="pip install ."
cd "$KA_LITE_DIR"
echo ".. Running $PIP_CMD..."
$PIP_CMD
if [ $? -ne 0 ]; then
    echo ".. Abort! Error/s encountered running '$PIP_CMD'."
    exit 1
fi

PIP_CMD="pip install wheel"
echo ".. Running $PIP_CMD..."
$PIP_CMD
if [ $? -ne 0 ]; then
    echo ".. Abort! Error/s encountered running '$PIP_CMD'."
    exit 1
fi

((STEP++))
echo "$STEP/$STEPS. Running 'make dist'..."

# MUST: Make sure we have a KALITE_PYTHON env var that points to python
# because `bin/kalite manage ...` will be called when we do `make assets`.
export KALITE_PYTHON="python"

cd "$KA_LITE_DIR"
MAKE_CMD="make dist"
echo ".. Running $MAKE_CMD..."
$MAKE_CMD
if [ $? -ne 0 ]; then
    echo ".. Abort!  Error/s encountered running '$MAKE_CMD'."
    exit 1
fi

((STEP++))
echo "$STEP/$STEPS. Installing PEX to create kalite PEX file"
PIP_CMD="pip install pex"
echo ".. Running $PIP_CMD..."
$PIP_CMD
if [ $? -ne 0 ]; then
    echo ".. Abort! Error/s encountered running '$PIP_CMD'."
    exit 1
fi

cd "$KA_LITE_DIR"
WHL_FILE="$(find dist/ -name 'ka_lite_static-*.whl')"
pex -o dist/kalite.pex -m kalite $WHL_FILE
if [ $? -ne 0 ]; then
    echo ".. Abort! Failed to build KA Lite pex file."
    exit 1
fi

((STEP++))
echo "Updating KA Lite installer version"
KA_LITE_VERSION="$(kalite --version)"
DOCS_PATH="$SCRIPTPATH/KA-Lite-Packages/docs"
sed -i '' "13s/{{ KA_LITE_VERSION }}/$KA_LITE_VERSION/g" "$DOCS_PATH/INTRODUCTION.rst.rtfd/TXT.rtf" && \
sed -i '' "12s/{{ KA_LITE_VERSION }}/$KA_LITE_VERSION/g" "$DOCS_PATH/SUMMARY.rtfd/TXT.rtf" && \
sed -i '' "12s/{{ KA_LITE_VERSION }}/$KA_LITE_VERSION/g" "$DOCS_PATH/README.rst.rtf"
if [ $? -ne 0 ]; then
    echo ".. Failed to update KA Lite installer version."
fi

ENV_CMD="rm -r $ENV_PATH/venv"
deactivate
echo ".. Removing $ENV_CMD..."
$ENV_CMD
if [ $? -ne 0 ]; then
    echo ".. Abort!  Error/s encountered running '$ENV_CMD'."
    exit 1
fi


# Build the Xcode project
((STEP++))
echo "$STEP/$STEPS. Building the Xcode project..."
if [ -d "$KA_LITE_PROJECT_DIR" ]; then
    # MUST: xcodebuild needs to be on the same directory as the .xcodeproj file
    cd "$KA_LITE_PROJECT_DIR"
    xcodebuild clean build
    if [ $? -ne 0 ]; then
        echo ".. Abort!  Running \"xcodebuild clean build\" failed!"
        exit 1
    fi
fi

# check if build of Xcode project succeeded
KA_LITE_APP_PATH="$KA_LITE_PROJECT_DIR/build/Release/KA-Lite.app"
if ! [ -d "$KA_LITE_APP_PATH" ]; then
    echo ".. Abort!  Build of '$KA_LITE_APP_PATH' failed!"
    exit 1
fi


# Check if to code-sign or not
((STEP++))
echo "$STEP/$STEPS. Checking if to code-sign the application or not..."
SIGNER_IDENTITY_APPLICATION="Developer ID Application: Foundation for Learning Equality, Inc. (H83B64B6AV)"
if [ -z ${IS_KALITE_RELEASE+0} ]; then 
    echo ".. Not a release, don't code-sign the application!"
else 
    echo ".. Release build so MUST code-sign the application..."
    codesign -d -s "$SIGNER_IDENTITY_APPLICATION" --force "$KA_LITE_APP_PATH"
    if [ $? -ne 0 ]; then
        echo ".. Abort!  Error/s encountered codesigning '$KA_LITE_APP_PATH'."
        exit 1
    fi
fi


# Build the KA-Lite  installer using `Packages` to generate the .pkg file.
((STEP++))
cd "$WORKING_DIR/.."
echo "$STEP/$STEPS. Building the .pkg file at '$TEMP_OUTPUT_PATH'..."

KALITE_PACKAGES_NAME="KA-Lite.pkg"
PACKAGES_PROJECT="$SCRIPTPATH/KA-Lite-Packages/KA-Lite.pkgproj"
PACKAGES_OUTPUT="$SCRIPTPATH/KA-Lite-Packages/build/$KALITE_PACKAGES_NAME"

$PACKAGES_EXEC $PACKAGES_PROJECT
if [ $? -ne 0 ]; then
    echo ".. Abort!  Error building the .pkg file with '$PACKAGES_EXEC'."
    exit 1
fi

echo ".. Checking if to productsign the package or not..."
OUTPUT_PKG="$TEMP_OUTPUT_PATH/$KALITE_PACKAGES_NAME"
SIGNER_IDENTITY_INSTALLER="Developer ID Installer: Foundation for Learning Equality, Inc. (H83B64B6AV)"
if [ -z ${IS_KALITE_RELEASE+0} ]; then 
    echo ".. Not a release, don't productsign the package!"
    mv -v $PACKAGES_OUTPUT $TEMP_OUTPUT_PATH
else 
    echo ".. Release build so MUST productsign the package..."
    productsign --sign "$SIGNER_IDENTITY_INSTALLER" "$PACKAGES_OUTPUT" "$OUTPUT_PKG"
    if [ $? -ne 0 ]; then
        echo ".. Abort!  Error/s encountered productsigning '$PACKAGES_OUTPUT'."
        exit 1
    fi
fi

# Remove the .dmg if it exists.
test -e "$DMG_PATH" && rm "$DMG_PATH"

# Add the README.md to the package.
# Copy the KA Lite logo to the package.
cp "$SCRIPTPATH/dmg-resources/README.md" "$TEMP_OUTPUT_PATH"
cp "$SCRIPTPATH/dmg-resources/ka-lite-logo.png" "$TEMP_OUTPUT_PATH"

echo "$STEP/$STEPS. Building the .dmg file at '$OUTPUT_PATH'..."
# Let's create the .dmg.
$CREATE_DMG \
    --volname "KA Lite Installer" \
    --volicon "$KA_LITE_ICNS_PATH" \
    --background "$TEMP_OUTPUT_PATH/ka-lite-logo.png" \
    --icon "KA-Lite.pkg" 100 170 \
    --icon "README.md" 300 170 \
    --icon "python-2.7.12-macosx10.6.pkg" 500 170 \
    --window-size 600 400 \
    "$DMG_PATH" \
    "$TEMP_OUTPUT_PATH"
if [ $? -ne 0 ]; then
    echo ".. Abort! Failed to build KA Lite dmg file."
    exit 1
fi

echo "Done!"
if [ -e "$DMG_PATH" ]; then
    # codesign the built DMG file
    # unlock the keychain first so we can access the private key
    # security unlock-keychain -p $KEYCHAIN_PASSWORD
    if [ -z ${IS_KALITE_RELEASE+0} ]; then 
        echo "Congratulations! Your newly built KA Lite installer is at '$DMG_PATH'."
    else
        codesign -s "$SIGNER_IDENTITY_APPLICATION" --force "$DMG_PATH"
        if [ $? -ne 0 ]; then
            echo "..Failed to codesign the newly built KA Lite installer at '$DMG_PATH'."
            exit 1
        fi
        echo "Congratulations! Your newly built KA Lite installer is at '$DMG_PATH'."
    fi
else
    echo "Sorry, something went wrong trying to build the installer at '$DMG_PATH'."
    exit 1
fi
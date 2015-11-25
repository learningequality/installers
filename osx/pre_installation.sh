#!/bin/bash

# What does this script do?
#    1. Unset environment variable: KALITE_PYTHON.
#    2. Remove the .plist file, kalite executable, ka-lite resources.
#    3. Check if the .plist file, kalite executable, ka-lite resources.
#    4. Display a console log for this process.
#
# Note: 
#    * This script always run on sudo.
#    * The files that will be remove will be display on the console log.
#    * Sometimes calling 'which' to check the executable exist is not enough 
#         so we check if the executable exist on the path we expected them to exist.
#         e.g the file has permission so it will not be called on which command.

#----------------------------------------------------------------------
# Global Variables
#----------------------------------------------------------------------
KALITE="kalite"
KALITE_PLIST="org.learningequality.kalite.plist"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
LIBRARY_PLIST="$LAUNCH_AGENTS/$KALITE_PLIST"
KALITE_EXECUTABLE_PATH="$(which $KALITE)"
KALITE_RESOURCES="/Users/Shared/ka-lite"
KALITE_USR_BIN_PATH="/usr/bin"
KALITE_USR_LOCAL_BIN_PATH="/usr/local/bin"

REMOVE_FILES_ARRAY=()

#----------------------------------------------------------------------
# Functions
#----------------------------------------------------------------------
function append() {
    eval $1[\${#$1[*]}]=$2
}

function remove_files_initiator {
    if [ -f $LIBRARY_PLIST ]; then
        append REMOVE_FILES_ARRAY $LIBRARY_PLIST
    fi

    if [ -d "$KALITE_RESOURCES" ]; then
        append REMOVE_FILES_ARRAY $KALITE_RESOURCES
    fi

    if which kalite > /dev/null 2>&1; then
        append REMOVE_FILES_ARRAY $KALITE_EXECUTABLE_PATH
    fi

    for file in "${REMOVE_FILES_ARRAY[@]}"; do
        if [ -e "${file}" ]; then
            echo "Now Removing file: ${file}"
            syslog -s -l error "Now Removing file: ${file}"
        fi
    done

    # Collect the directories and files to remove
    sudo rm -Rf ${REMOVE_FILES_ARRAY[*]}

    for file in "${REMOVE_FILES_ARRAY[@]}"; do
        if [ -e "${file}" ]; then
            echo "An error must have occurred since a file that was supposed to be"
            echo "removed still exists: ${file}"
            syslog -s -l error "Removed file still exists: ${file}"
            echo ""
        fi
    done

}

function check_kalite_exc_collector {
    if [ -f "$KALITE_USR_BIN_PATH/$KALITE" ]; then
        append REMOVE_FILES_ARRAY $KALITE_USR_BIN_PATH/$KALITE
    else
        echo "'$KALITE_USR_BIN_PATH/$KALITE' executable not found."
        syslog -s -l error "'$KALITE_USR_BIN_PATH/$KALITE' executable not found."
    fi

    if [ -f "$KALITE_USR_LOCAL_BIN_PATH/$KALITE" ]; then
        append REMOVE_FILES_ARRAY $KALITE_USR_LOCAL_BIN_PATH/$KALITE
    else
        echo "'$KALITE_USR_LOCAL_BIN_PATH/$KALITE' executable not found."
        syslog -s -l error "'$KALITE_USR_BIN_PATH/$KALITE' executable not found."
    fi
    remove_files_initiator
}

#----------------------------------------------------------------------
# Script
#----------------------------------------------------------------------
ENV=$(env)
syslog -s -l error "Packages pre-installation initialize with env:'\n'$ENV" 

echo "Unset the KALITE_PYTHON environment variable"
launchctl unsetenv KALITE_PYTHON

echo "Removing files..."
remove_files_initiator

echo "Check if the kalite executable is remove in '$KALITE_USR_BIN_PATH' and '$KALITE_USR_LOCAL_BIN_PATH'..."
check_kalite_exc_collector

echo "Done!"







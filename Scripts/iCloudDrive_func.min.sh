#!/bin/bash
#Joel Bruner (repo: https://github.com/brunerd, blog: https://brunerd.com/blog)
#iCloudDrive (min) - gets the iCloud Drive status for a console user

#############
# FUNCTIONS #
#############

#ridiculously minified function
function iCloudDrive()(consoleUser=$(stat -f %Su /dev/console);if [ "${consoleUser}" = "root" ]; then consoleUser=$(/usr/bin/last -1 -t console | awk '{print $1}');fi;userHome=$(dscl /Local/Default -read /Users/"${consoleUser}" NFSHomeDirectory | awk '{print $NF}');if [ -d "${userHome}/Library/Mobile Documents" ]; then return 0; else return 1;fi)

########
# MAIN #
########

#example function usage, leverages the return value (0=On, 1=Off)
if iCloudDrive; then
	echo "iCloud Drive is ON"
	exit 0
else
	echo "iCloud Drive is OFF"
	exit 1
fi

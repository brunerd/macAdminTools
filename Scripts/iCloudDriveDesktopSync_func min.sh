#!/bin/bash
#Joel Bruner (repo: https://github.com/brunerd, blog: https://brunerd.com/blog)
#iCloudDriveDesktopSync (min) - gets the iCloud Drive Desktop and Document Sync Status for the console user

#############
# FUNCTIONS #
#############

#here's your minified function
function iCloudDriveDesktopSync()(consoleUser=$(stat -f %Su /dev/console);if [ "${consoleUser}" = "root" ]; then consoleUser=$(/usr/bin/last -1 -t console | awk '{print $1}');fi;xattr_desktop=$(sudo -u $consoleUser /bin/sh -c 'xattr -p com.apple.icloud.desktop ~/Desktop 2>/dev/null');if [ -z "${xattr_desktop}" ]; then return 1;else return 0;fi)

#example function usage, if leverages the return values
if iCloudDriveDesktopSync; then
	echo "iCloud Drive Desktop and Documents Sync is ON"
	exit 0
else
	echo "iCloud Drive Desktop and Documents Sync is OFF"
	exit 1
fi
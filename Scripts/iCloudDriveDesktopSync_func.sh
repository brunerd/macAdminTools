#!/bin/bash
#Joel Bruner (repo: https://github.com/brunerd, blog: https://brunerd.com/blog)
#iCloudDriveDesktopSync - gets the iCloud Drive Desktop and Document Sync Status for the console user

#############
# FUNCTIONS #
#############

#must be run as root
function iCloudDriveDesktopSync()(

	consoleUser=$(stat -f %Su /dev/console)

	#if root (loginwindow) grab the last console user
	[ "${consoleUser}" = "root" ] && consoleUser=$(/usr/bin/last -1 -t console | awk '{print $1}')

	homeFolder=$(/usr/libexec/PlistBuddy -c "print dsAttrTypeStandard\:NFSHomeDirectory:0" /dev/stdin 2>/dev/null <<< "$(dscl -plist . -read "/Users/${consoleUser}" NFSHomeDirectory)")

	#Checks for multiple attributes: macOS Sequoia (com.apple.file-provider-domain-id) and previous OSes (com.apple.icloud.desktop)
	grep -q -E 'com\.apple\.file-provider-domain-id|com\.apple\.icloud\.desktop' <<< $(xattr "${homeFolder}/Desktop") && return 0 || return 1
)

#example function usage, if leverages the return values
if iCloudDriveDesktopSync; then
	echo "iCloud Drive Desktop and Documents Sync is ON"
	exit 0
else
	echo "iCloud Drive Desktop and Documents Sync is OFF"
	exit 1
fi

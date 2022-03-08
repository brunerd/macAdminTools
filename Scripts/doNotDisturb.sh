#!/bin/bash
#doNotDisturb (grep) (20220227) Copyright (c) 2022 Joel Bruner (https://github.com/brunerd)
#Licensed under the MIT License

#An example of detecting Do Not Disturb (macOS 10.13-12)

function doNotDisturb()(

	OS_major="$(sw_vers -productVersion | cut -d. -f1)"
	consoleUserID="$(stat -f %u /dev/console)"
	consoleUser="$(stat -f %Su /dev/console)"
	
	#get Do Not Disturb status
	if [ "${OS_major}" = "10" ]; then
		#returns c-cstyle boolean 0 (off) or 1 (on)
		dndStatus="$(launchctl asuser ${consoleUserID} sudo -u ${consoleUser} defaults -currentHost read com.apple.notificationcenterui doNotDisturb 2>/dev/null)"

		#eval c-style boolean and return shell style value
		[ "${dndStatus}" = "1" ] && return 0 || return 1
	#this only works for macOS 11 - macOS12 does not affect any of the settings in com.apple.ncprefs
	elif [ "${OS_major}" = "11" ]; then
		#returns "true" or [blank]
		dndStatus="$(/usr/libexec/PlistBuddy -c "print :userPref:enabled" /dev/stdin 2>/dev/null <<< "$(plutil -extract dnd_prefs xml1 -o - /dev/stdin <<< "$(launchctl asuser ${consoleUserID} sudo -u ${consoleUser} defaults export com.apple.ncprefs.plist -)" | xmllint --xpath "string(//data)" - | base64 --decode | plutil -convert xml1 - -o -)")"

		#if we have ANYTHING it is ON (return 0) otherwise fail (return 1)
		[ -n "${dndStatus}" ] && return 0 || return 1
	elif [ "${OS_major}" -ge "12" ]; then
		consoleUserHomeFolder=$(dscl . -read /Users/"${consoleUser}" NFSHomeDirectory | awk -F ': ' '{print $2}')
		file_assertions="${consoleUserHomeFolder}/Library/DoNotDisturb/DB/Assertions.json"

		#if Assertions.json file does NOT exist, then DnD is OFF
		[ ! -f "${file_assertions}" ] && return 1

		#simply check for storeAssertionRecords existence, usually found at: /data/0/storeAssertionRecords (and only exists when ON)
		! grep -q "storeAssertionRecords" "${file_assertions}" 2>/dev/null && return 1 || return 0
	fi
)
if doNotDisturb; then
	echo "DnD/Focus is ON... don't be a jerk"
else
	echo "DnD/Focus is OFF"
fi

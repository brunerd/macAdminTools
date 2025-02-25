#!/bin/sh
#Apple Intelligence Availability (20250225) - A Jamf extension attribute and generic function (getAIStatus) to check the status of Apple Intelligence
#Copyright (c) 2024 Joel Bruner (https://github.com/brunerd, https://brunerd.com). Licensed under the MIT License. Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
set -x
#works for both macOS 15.3 and under and 15.4 and up (which no longer uses .GlobalPreferences com.apple.gms.availability.key)
function getAIStatus(){
	#get console user
	local consoleUser=$(stat -f %Su /dev/console)	

	#if root (loginwindow) grab the last console user
	[ "${consoleUser}" = "root" ] && local consoleUser=$(/usr/bin/last -1 -t console | awk '{print $1}')
	
	#get ID of the user
	local consoleUserID=$(id -u "${consoleUser}")

	#get com.apple.CloudSubscriptionFeatures.optIn as the user
	local data=$(launchctl asuser "${consoleUserID}" sudo su "${consoleUser}" -c "defaults export com.apple.CloudSubscriptionFeatures.optIn -")

	#test if "device" key exists no iCloud sign-in
	if /usr/libexec/PlistBuddy -c "print :device" /dev/stdin <<< "${data}" 2>/dev/null 1>&2; then
		local value=$(/usr/libexec/PlistBuddy -c "print :device" /dev/stdin <<< "${data}" 2>/dev/null)
	#we might have iCloud sign-in which changes key name from "device" to the iCloud AccountDSID
	else
		#get MobileMeAccounts prefs as the user
		local MobileMeAccounts=$(launchctl asuser "${consoleUserID}" sudo su "${consoleUser}" -c "defaults export MobileMeAccounts -")	

		#get index where AccountUUID exists, usually 0 but not always (only primary iCloud account has this key not additional Mail accounts)
		local AccountsIndex=$(xmllint --xpath 'count(/plist/dict/key[text()="Accounts"]/following-sibling::array/dict[key="AccountUUID"]/preceding-sibling::dict)' - <<< "${MobileMeAccounts}")

		#get the AccountDSID from iCloud dictionary the Accounts array 
		local AccountDSID
		#only if found 
		if AccountDSID=$(/usr/libexec/PlistBuddy -c "print :Accounts:${AccountsIndex}:AccountDSID" /dev/stdin 2>/dev/null <<< "${MobileMeAccounts}"); then
			local value=$(/usr/libexec/PlistBuddy -c "print :${AccountDSID}" /dev/stdin <<< "${data}" 2>/dev/null)
		fi
	fi

	#interpret it
	case "${value}" in
		'true') interpretation="On";;
		'false') interpretation="Off";;
		'') interpretation="Not Set";;
		#can't be anything but these - otherwise key doesn't exist so it'll fall through below to "Not Set ()"
	esac
	
	echo "${interpretation} ($value)"
}

[ $UID != 0 ] && { echo "Run as root, exiting." >&2; exit 1; }

#usual responses: "On (true)", "Off (false)", or "Not Set ()"
result=$(getAIStatus)

echo "<result>${result}</result>"

exit 0

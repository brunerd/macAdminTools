#!/bin/sh
#Apple Intelligence Availability (20250225) - A Jamf extension attribute and generic function (getAIStatus) to check the status of Apple Intelligence
#Copyright (c) 2024 Joel Bruner (https://github.com/brunerd, https://brunerd.com). Licensed under the MIT License. Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#works for both macOS 15.3 and under and 15.4 and up
function getAIStatus(){
	#get console user
	local consoleUser=$(stat -f %Su /dev/console)	

	#if root (loginwindow) grab the last console user
	[ "${consoleUser}" = "root" ] && local consoleUser=$(/usr/bin/last -1 -t console | awk '{print $1}')
	
	#get ID of the user
	local consoleUserID=$(id -u "${consoleUser}")

	#get com.apple.CloudSubscriptionFeatures.optIn as the user
	local data=$(launchctl asuser "${consoleUserID}" sudo su "${consoleUser}" -c "defaults export com.apple.CloudSubscriptionFeatures.optIn -")

	#test if key device exists (only on 15.4 and up)
	if /usr/libexec/PlistBuddy -c "print :device" /dev/stdin <<< "${data}" 2>/dev/null 1>&2; then
		local value=$(/usr/libexec/PlistBuddy -c "print :device" /dev/stdin <<< "${data}" 2>/dev/null)
		
		#interpret it
		case "${value}" in
			'true') interpretation="On";;
			'false') interpretation="Off";;
			#can't be anytging but these - otherwise key doesn't exist so it'll fall through below to "Not Set ()"
		esac
	#fall back to earlier behavior (15.3 and earlier)
	else	
		#get .GlobalPreferences as the user
		data=$(launchctl asuser "${consoleUserID}" sudo su "${consoleUser}" -c "defaults export .GlobalPreferences -")
	
		#test if key exists and bail if not
		if /usr/libexec/PlistBuddy -c "print :com.apple.gms.availability.key" /dev/stdin <<< "${data}" 2>/dev/null 1>&2; then
			#PlistBuddy gives us the raw binary plist data BUT it appends an extraneous newline (0x0a) character to the end* which corrupts it *(offset_table_start)
			#perl chomps off the last newline and then plutil can extract the first element of the array (0)
			local value=$(/usr/libexec/PlistBuddy -c "print :com.apple.gms.availability.key" /dev/stdin <<< "${data}" | perl -pe 'chomp if eof' | plutil -extract 0 raw - -o -)
			#Returns values: 2 (Off), 0 (On), or not set
			#In 15.4 the value is always 2, regardless of Apple Intelligence toggle switch in System Settings
		fi
		
		#interpret it (be honest we are "reading tea leaves" here and it could be subject to change)
		case "${value}" in
			0) interpretation="On";;
			2) interpretation="Off";;
			'')interpretation="Not Set";;
			*) interpretation="Unknown";;
		esac
	fi
		
	echo "${interpretation} ($value)"
}

[ $UID != 0 ] && { echo "Run as root, exiting." >&2; exit 1; }

#15.3 and under usual responses: "On (0)", "Off (2)", "Unknown (1)" or "Not Set ()"
#15.4 and up usual responses: "On (true)", "Off (false)"
result=$(getAIStatus)

echo "<result>${result}</result>"

exit 0

#!/bin/sh
#Apple Intelligence Availability - A Jamf extension attribute and generic function (ai_gms_availability_value) to check the status of Apple Intelligence
#Copyright (c) 2024 Joel Bruner (https://github.com/brunerd, https://brunerd.com). Licensed under the MIT License. Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

function ai_gms_availability_value(){
	#get console user
	local consoleUser=$(stat -f %Su /dev/console)	

	#if root (loginwindow) grab the last console user
	[ "${consoleUser}" = "root" ] && local consoleUser=$(/usr/bin/last -1 -t console | awk '{print $1}')
	
	#get ID of the user
	local consoleUserID=$(id -u "${consoleUser}")

	#get .GlobalPreferences as the user
	local data=$(launchctl asuser "${consoleUserID}" sudo su "${consoleUser}" -c "defaults export .GlobalPreferences -")

	#test if key exists and bail if not
	! /usr/libexec/PlistBuddy -c "print :com.apple.gms.availability.key" /dev/stdin <<< "${data}" 2>/dev/null 1>&2 && return

	#PlistBuddy gives us the raw binary plist data BUT it appends an extraneous newline (0x0a) character to the end* which corrupts it *(offset_table_start)
	#perl chomps off the last newline and then plutil can extracts the first element of the array (0)
	/usr/libexec/PlistBuddy -c "print :com.apple.gms.availability.key" /dev/stdin <<< "${data}" | perl -pe 'chomp if eof' | plutil -extract 0 raw - -o -
	#Returns values: 2 (Off), 0 (On), or not set
}

[ $UID != 0 ] && { echo "Run as root, exiting." >&2; exit 1; }

#get the result
value=$(ai_gms_availability_value)

#interpret it (be honest we are "reading tea leaves" here and it could be subject to change)
case "${value}" in
	0) interpretation="On";;
	2) interpretation="Off";;
	'')interpretation="Not Set";;
	*) interpretation="Unknown";;
esac

#usual responses: "On (0)", "Off (2)", or "Not Set ()"
result="${interpretation} ($value)"

echo "<result>${result}</result>"

exit 0

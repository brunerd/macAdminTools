#!/bin/bash
#Joel Bruner - Jamf Extension attribute to outputs the per-SSID MAC randomization setting 
#This EA can be used for a Smart Group that allows a Mac to upgrade to Sequoia once Wi-Fi is set to 'off' (see setPrivateMACAddressMode.sh)
#Possible values of PrivateMACAddressModeUserSetting are: off, static, rotating, or NOT_SET

: <<-LICENSE_BLOCK
OS-Private MAC Address Mode Copyright (c) 2024 Joel Bruner (https://github.com/brunerd)
Licensed under the MIT License
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
LICENSE_BLOCK

#############
# VARIABLES #
#############

#hardcode one or more SSIDs, comma or or newline delimited (otherwise report on all known networks)
SSIDS=""

#delimiter to you between mode and SSID
output_delimiter="|"

#newlines or commas for our list of SSIDs both discovered and hardcoded
SSID_delimiters=$'\n,'

#############
# FUNCTIONS #
#############

function getModeForSSID(){

	#trim of any leading or tailing whitespace in case hardcoded has space
	local SSID="$(sed -e $'s/^[ \t]*//g' -e $'s/[ \t]*$//g' <<< ${1})"

	#find key in com.apple.wifi.known-networks, possible values are: off, static, rotating
	#MDM distributed Wi-Fi payloads populate this plist still and key is respected) after reboot
	[ -n "${SSID}" ] && local PrivateMACAddressMode=$(/usr/libexec/PlistBuddy -c "print :wifi.network.ssid.'${SSID}':PrivateMACAddressModeUserSetting" /Library/Preferences/com.apple.wifi.known-networks.plist 2>/dev/null)
		
	echo "${PrivateMACAddressMode:-NOT_SET}${output_delimiter}${SSID}"
}	

########
# MAIN #
########

#exit quickly if plist does not exist
! [ -e "/Library/Preferences/com.apple.wifi.known-networks.plist" ] && { echo "<result>${result}</result>"; exit; } 

#if nothing specified, use SSIDs already known
if [ -z "${SSIDS}" ]; then
	#get all known networks
	KNOWN_SSIDS=$(defaults export /Library/Preferences/com.apple.wifi.known-networks.plist - | xmllint --xpath "/plist/dict/key/text()" /dev/stdin | sed "s/^wifi\.network\.ssid\.//g")
	SSIDS="${KNOWN_SSIDS}"
fi

#finally go through one or more SSIDs
IFS="${SSID_delimiters}"
for SSID in $SSIDS; do
	[ -n "${result}" ] && nl=$'\n'
	result+=${nl}$(getModeForSSID "${SSID}")
done

echo "<result>${result}</result>"

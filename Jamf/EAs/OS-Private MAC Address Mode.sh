#!/bin/bash
#OS-Private MAC Address Mode (20241009) - Jamf Extension attribute to outputs the per-SSID MAC randomization setting 
#This EA can be used for a Smart Group that allows a Mac to upgrade to Sequoia once Wi-Fi is set to 'off' (see setPrivateMACAddressMode.sh)
#Possible values of PrivateMACAddressModeUserSetting are: off, static, rotating, or NOT_SET
#Possible values of GLOBAL_DEFAULT_PRIVATE_OFF (aka the awfully named PrivateMACAddressModeSystemSetting) are: 1 (Private Address mode defaults to off), 0 (Private Address mode defaults to on), or "NOT_SET" 

#Sample output:
#<result>1|(disable)PrivateMACAddressModeSystemSetting
#rotating|SomeSSID
#off|SomeOtherSSID
#static|CafeSSID</result>

: <<-LICENSE_BLOCK
OS-Private MAC Address Mode - Copyright (c) 2024 Joel Bruner (https://github.com/brunerd)
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

	#trim of any leading or trailing whitespace in case hardcoded has space
	local SSID="$(sed -e $'s/^[ \t]*//g' -e $'s/[ \t]*$//g' <<< ${1})"

	#find key in com.apple.wifi.known-networks, possible values are: off, static, rotating
	#MDM distributed Wi-Fi payloads populate this plist still and key is respected) after reboot
	[ -n "${SSID}" ] && local PrivateMACAddressMode=$(/usr/libexec/PlistBuddy -c "print :wifi.network.ssid.'${SSID}':PrivateMACAddressModeUserSetting" /Library/Preferences/com.apple.wifi.known-networks.plist 2>/dev/null)
		
	echo "${PrivateMACAddressMode:-NOT_SET}${output_delimiter}${SSID}"
}	

########
# MAIN #
########

[ $UID != 0 ] && { echo "Run as root!" >&2 ; exit 1; }

#(disable)`PrivateMACAddressModeSystemSetting` sets the global _default_ mode for newly joined SSIDs, if `PrivateMACAddressModeUserSetting` already set to static/rotating for an existing SSID, it will have no effect 
#ref: https://community.jamf.com/t5/jamf-pro/disable-wi-fi-private-mac-address-on-macos-15/m-p/326131
sysConfigAirportPrefs="/Library/Preferences/SystemConfiguration/com.apple.airport.preferences.plist"
if [ -e "${sysConfigAirportPrefs}" ]; then
	#`PrivateMACAddressModeSystemSetting` is poorly named, pretend it's a shell return code or prepend (disable) to make sense of it?
	globalSetting=$(defaults read "${sysConfigAirportPrefs}" "PrivateMACAddressModeSystemSetting" 2>/dev/null)
	#0="Default Private Address Mode is ON (disable false)", 1="Default Private Address Mode is OFF (disable true)"
	result="${globalSetting:-NOT_SET}${output_delimiter}(disable)PrivateMACAddressModeSystemSetting"	
fi

#only if plist exists
if [ -e "/Library/Preferences/com.apple.wifi.known-networks.plist" ]; then
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
fi

echo "<result>${result}</result>"

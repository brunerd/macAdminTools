#!/bin/bash
#getPrivateMACAddressMode (20241009) - outputs human readable per-SSID Private MAC Address randomization settings introduced in Sequoia
#possible values of PrivateMACAddressModeUserSetting are: off, static, rotating, or NOT_SET
#possible values of PrivateMACAddressModeSystemSetting are: 0 (ON), 1 (OFF), or NOT_SET

#sample output:
#PrivateMACAddressModeSystemSetting: 1 (OFF)
#
#SSID: SomeSSID
#MODE: rotating

: <<-LICENSE_BLOCK
getPrivateMACAddressMode Copyright (c) 2024 Joel Bruner (https://github.com/brunerd)
Licensed under the MIT License
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
LICENSE_BLOCK


#############
# VARIABLES #
#############

#hardcode an SSID(s) comma or or newline delimited (otherwise will list all known networks)
SSIDS="$1"

#newlines or commas for our list of SSIDs both discovered and hardcoded
SSID_delimiters=$'\n,'

#############
# FUNCTIONS #
#############

function getModeForSSID(){

	#trim of any leading or tailing whitespace in case hardcoded has space
	local SSID="$(sed -e $'s/^[ \t]*//g' -e $'s/[ \t]*$//g' <<< ${1})"

	#find key in com.apple.wifi.known-networks, possible values are: off, static, rotating
	[ -n "${SSID}" ] && local PrivateMACAddressMode=$(/usr/libexec/PlistBuddy -c "print :wifi.network.ssid.'${SSID}':PrivateMACAddressModeUserSetting" /Library/Preferences/com.apple.wifi.known-networks.plist 2>/dev/null)
	
	#fall back to NOT_SET is nothing found	
	echo "${PrivateMACAddressMode:-NOT_SET}"
}	

########
# MAIN #
########

[ $UID != 0 ] && { echo "Run as root!" >&2 ; exit 1; }

#`PrivateMACAddressModeSystemSetting` sets the global _default_ mode for newly joined SSIDs, if `PrivateMACAddressModeUserSetting` already set to static/rotating will have no effect an SSID
#see: https://community.jamf.com/t5/jamf-pro/disable-wi-fi-private-mac-address-on-macos-15/m-p/326131 and 
sysConfigAirportPrefs="/Library/Preferences/SystemConfiguration/com.apple.airport.preferences.plist"
if [ -e "${sysConfigAirportPrefs}" ]; then
	globalSetting=$(defaults read "${sysConfigAirportPrefs}" "PrivateMACAddressModeSystemSetting" 2>/dev/null)
	if [ -n "${globalSetting}" ]; then
		#`PrivateMACAddressModeSystemSetting` is poorly named, pretend it's a shell return code or prepend (disable) to make sense of it?
		#1="Default Private Address Mode is OFF (disable true)" or else 0="Default Private Address Mode is ON (disable false)",
		((globalSetting)) && meaning=" (true)" || meaning=" (false)"
	fi
	#the key name truly lacks clarity let's help it out and add some "meaning"
	echo "(disable)PrivateMACAddressModeSystemSetting: ${globalSetting:-NOT_SET}${meaning}"
	echo
fi

#if nothing specified
if [ -z "${SSIDS}" ]; then
	#get all known networks
	SSIDS=$(defaults export /Library/Preferences/com.apple.wifi.known-networks.plist - | xmllint --xpath "/plist/dict/key/text()" /dev/stdin | sed "s/^wifi\.network\.ssid\.//g")
fi

#go through one or more SSIDs
IFS="${SSID_delimiters}"
for SSID in $SSIDS; do
	#extra line above if more than one go around
	((i)) && echo
	echo "SSID: ${SSID}"
	echo "MODE: $(getModeForSSID "${SSID}")"
	let i++
done

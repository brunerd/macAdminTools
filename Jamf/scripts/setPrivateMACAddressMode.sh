#!/bin/bash
#setPrivateMACAddressMode - set the MAC private address mode (randomization) for the curent or specified WiFi SSID
#Note: Change does not take affect until after restart (or an upgrade) unless someone knows a clever `kill -HUP`
#Sonoma and under: Can be used to prevent MAC randomization after upgrade to Sequoia
#See Jamf Extension Attribute `OS-Private MAC Address Mode` for reporting and Smart Group usage

: <<-LICENSE_BLOCK
setPrivateMACAddressMode Copyright (c) 2024 Joel Bruner (https://github.com/brunerd)
Licensed under the MIT License
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
LICENSE_BLOCK

#############
# VARIABLES #
#############
#use Jamf script parameters or hardcode (HC) for other MDMs

#the randomization mode (PrivateMACAddressModeUserSetting): empty/default is "off", other values: "static" (Fixed), "rotating"
mode_HC="off"
mode="${4:-$mode_HC}"

#specify multiple SSIDs, if none specified will use current Wi-Fi SSID 
SSIDS_HC=""
SSIDS="${5:-$SSIDS_HC}"

#default delimiter for possible SSID list is comma, hardcode or specify otherwise
delimiter_HC=$','
delimiter="${6:-$delimiter_HC}"

#############
# FUNCTIONS #
#############

#if you don't have Jamf... I suppose just delete this function and replace all `jamflog` with `echo`
function jamflog(){
	#unset xtrace if enabled to quiet this function
	[ -n "${-//[^x]/}" ] && { local xTrace=1; set +x; } &>/dev/null
	#take input either as a parameter or piped in
	if [ -n "${1}" ]; then local input="${1}"; elif [ ! -t '0' ]; then local input=$(cat); else return; fi
	#default destination is override-able
	local logFile="${2:-/var/log/jamf.log}"
	#if we cannot write to the log, unset and tee simply echoes
	([ -e "${logFile}" ] && [ ! -w "${logFile}" ]) && unset logFile
	#process each line
	local IFS=$'\n'
	for line in ${input}; do
		#this will tee to jamf.log in the jamf log format: <Day> <Month> DD HH:MM:SS <Computer Name> ProcessName[PID]: <Message>
		builtin echo "$(/bin/date +'%a %b %d %H:%M:%S') ${jamflog_myComputerName:="$(/usr/sbin/scutil --get ComputerName)"} ${jamflog_myName:="$(/usr/bin/basename "${0%.*}")"}[${myPID:=$$}]: ${line}" | /usr/bin/tee -a "${logFile}" 2>/dev/null
	done
	#re-enable xtrace if it was on
	[ "${xTrace:-0}" = 1 ] && { set -x; } &>/dev/null
}

function systemCheck(){
	[ $UID != 0 ] && { echo "Run as root"; exit 1; }

	case "${mode}" in
		"off"|"static"|"rotating"):;;
		*)jamflog "Invalid mode: $mode, exiting";exit 1;;
	esac
}

#this will overide MDM DisableAssociationMACRandomization even if set to TRUE, although when profile applied will remove this value from plist but can be re-added
function setSSID(){
	#bail if SSID never joined, creating a single keyed entry will royally screw up WiFi
	if ! /usr/libexec/PlistBuddy -c "print :wifi.network.ssid.'${SSID}'" /Library/Preferences/com.apple.wifi.known-networks.plist 2>/dev/null 1>&2; then
		jamflog "[ERROR] SSID: ${SSID} never joined, skipping"
		return 1
	fi
	
	#get current mode from com.apple.wifi.known-networks, possible values are: off, static, rotating
	local PrivateMACAddressMode=$(/usr/libexec/PlistBuddy -c "print :wifi.network.ssid.'${SSID}':PrivateMACAddressModeUserSetting" /Library/Preferences/com.apple.wifi.known-networks.plist 2>/dev/null)
	
	#if nothing found then use add method
	if [ -z "${PrivateMACAddressMode}" ] ; then
		/usr/libexec/PlistBuddy -c "add :wifi.network.ssid.'${SSID}':PrivateMACAddressModeUserSetting string ${mode}" /Library/Preferences/com.apple.wifi.known-networks.plist
	#bail if change not needed
	elif [ "${PrivateMACAddressMode}" = "${mode}" ]; then
		jamflog "[INFO] SSID \"$SSID\" already set to \"$mode\", no change"
		return 0
	#use set for existing key
	else 
		/usr/libexec/PlistBuddy -c "set :wifi.network.ssid.'${SSID}':PrivateMACAddressModeUserSetting ${mode}" /Library/Preferences/com.apple.wifi.known-networks.plist
	fi
	local exitCode=$?
	
	#any non-zero code
	if ((exitCode)); then
		jamflog "[ERROR] code: $exitCode trying to set MAC Address mode for SSID \"$SSID\" to \"$mode\""
	else
		jamflog "SSID \"$SSID\" set to \"$mode\" MAC address mode"
	fi

	return $exitCode
}


########
# MAIN #
########

systemCheck

#if not supplied use the current SSID
if [ -z "${SSIDS}" ]; then
	#get network SSID (can take hella long time ~6s but Sequoia broke networksetup -getairportnetwork method)
	#https://snelson.us/2024/09/determining-a-macs-ssid-like-an-animal/
	#jamflog "Getting SSID..."
	SSIDS=$(system_profiler -detailLevel basic SPAirPortDataType | awk '/Current Network Information:/ { getline; print substr($0, 13, (length($0) - 13)); exit }')
fi

#if still blank, bail
if [ -z "${SSIDS}" ]; then
	jamflog "[ERROR] No SSID specified, no WiFi connection, exiting."
	exit 1
fi

#finally go through one or more SSIDs
IFS="$delimiter"
for SSID in $SSIDS; do
	setSSID "${SSID}"
	#keep tally for zero/non-zero exit code
	exitCode=$(($? + exitCode))	
done

exit ${exitCode:-0}

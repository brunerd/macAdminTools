#!/bin/bash
#setPrivateMACAddressMode - set the mode of macOS Sequoia's Private Address mode (aka MAC randomization) for the curent or specified WiFi SSID
#Notes: 
#1) Sonoma and under: Can be used to prevent MAC randomization upon upgrade to Sequoia, has no effect before upgrade to Sequoia
#2) Sequoia and up: Changes reliably take effect after restart... for the brave, set restartWiFi_HC="1" do this without reboot
#3) All macOS versions: Deploying a config profile with a Wi-Fi payload will rewrite all data for an SSID in com.apple.wifi.known-networks

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

#Restart Wi-Fi - causes the changes to take effect without reboot BUT you better make sure your Wi-Fi reconnects
#0=off, 1=on
restartWiFi_HC="0"
#how long to wait after powering WiFi back up to report on MAC address, 7 seems good, 5 is cutting close?
reconnectWaitSec="7"

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
		*)jamflog "[ERROR] Invalid mode: $mode, exiting";exit 1;;
	esac
}

#this will overide MDM DisableAssociationMACRandomization even if set to TRUE, although when profile applied will remove this value from plist but can be re-added
function setSSIDMode(){
	#bail if SSID never joined, creating a single keyed entry will royally screw up WiFi
	if ! /usr/libexec/PlistBuddy -c "print :wifi.network.ssid.'${SSID}'" /Library/Preferences/com.apple.wifi.known-networks.plist 2>/dev/null 1>&2; then
		jamflog "[ERROR] SSID: ${SSID} never joined, skipping"
		return 1
	fi
	
	#get current mode from com.apple.wifi.known-networks, possible values are: off, static, rotating
	local PrivateMACAddressMode=$(/usr/libexec/PlistBuddy -c "print :wifi.network.ssid.'${SSID}':PrivateMACAddressModeUserSetting" /Library/Preferences/com.apple.wifi.known-networks.plist 2>/dev/null)
	
	#bail if change not needed
	if [ "${PrivateMACAddressMode}" = "${mode}" ]; then
		jamflog "[INFO] SSID \"$SSID\" already set to \"$mode\", no change"
		return 0
	fi
	

	#make sure nothing cached gets written back if System Settings is open
	pgrep -x -q "System Settings" && { jamflog "[INFO] Closing System Settings" ; killall "System Settings"; sleep .5; }

	#if nothing found then use add method
	if [ -z "${PrivateMACAddressMode}" ] ; then
		/usr/libexec/PlistBuddy -c "add :wifi.network.ssid.'${SSID}':PrivateMACAddressModeUserSetting string ${mode}" /Library/Preferences/com.apple.wifi.known-networks.plist
	#use set for existing key
	else		
		#write the change
		/usr/libexec/PlistBuddy -c "set :wifi.network.ssid.'${SSID}':PrivateMACAddressModeUserSetting ${mode}" /Library/Preferences/com.apple.wifi.known-networks.plist
	fi
	local exitCode=$?

	#any non-zero code
	if ((exitCode)); then
		jamflog "[ERROR] code: $exitCode trying to set MAC Address mode for SSID \"${SSID}\" to \"$mode\""
	else
		jamflog "[INFO] SSID \"${SSID}\" set to \"$mode\" MAC address mode"
	fi
	
	#knock the juke box fonzy style (actually thanks MacAdmins @boberito) if restsartWiFi=1 and this is Sequoia and up
	if ((restartWiFi_HC)) && [ $(sw_vers -productVersion | cut -d. -f1) -ge 15 ]; then
		jamflog "[INFO] Restart Wi-Fi enabled: restarting cfprefsd, airportd"
		#get actual network interface (usually en0)
		networkInterface_WiFi=$(networksetup -listallhardwareports | grep -A1 "Hardware Port: Wi-Fi" | awk -F ': ' '/Device:/{print $2}')
		MAC_before="$(getWiFiMACAddress ${networkInterface_WiFi})"
		jamflog "[INFO] MAC Address (${networkInterface_WiFi:=en0}) before: ${MAC_before}"
		#make sure the defaults system is on the same page since we used PlistBuddy
		killall cfprefsd; sleep .5
		#this will make the airport toolbar and System Settings aware of the change but _MAC is still randomized_
		killall airportd; sleep .5
		jamflog "[INFO] Powering down Wi-Fi (${networkInterface_WiFi})"
		#down the interface
		networksetup -setairportpower "${networkInterface_WiFi}" off; sleep 1
		jamflog "[INFO] Powering up Wi-Fi (${networkInterface_WiFi}) and waiting ${reconnectWaitSec} seconds..."
		#up the interface
		networksetup -setairportpower "${networkInterface_WiFi}" on
		#we really don't know if we will reconnect or how it could take but let's wait a smidge and see
		sleep "${reconnectWaitSec}"
		#if we are active let's see what the MAC is (it doesn't change until it connects to WiFi again)
		if [ "$(ifconfig ${networkInterface_WiFi} | awk -F ': ' '/status/{print $2}')" = "active" ]; then
			MAC_after="$(getWiFiMACAddress ${networkInterface_WiFi})"
			if [ "${MAC_before}" != "${MAC_after}" ]; then
				jamflog "[INFO] SUCCESS! MAC Address (${networkInterface_WiFi}) after: ${MAC_after}"
			else
				jamflog "[ERROR] MAC Address (${networkInterface_WiFi}) unchanged after: ${MAC_after}"
			fi
		else
			jamflog "[WARN] ${networkInterface_WiFi} did not reconnect after wating ${reconnectWaitSec} seconds"
		fi
	fi

	return $exitCode
}

function getWiFiMACAddress(){
	local interface="${1:-en0}"
	ifconfig "${interface}" 2>/dev/null | grep ether | cut -d ' ' -f2
}

########
# MAIN #
########

systemCheck

#if not supplied use the current SSID
if [ -z "${SSIDS}" ]; then
	#jamflog "Getting SSID..."
	#get the SSID _quickly_
	currrent_SSID=$(ipconfig getsummary en0 | awk -F ' SSID : ' '/ SSID : / {print $2}')

	#one more attempt to get network SSID (in case en0 wasn't our WiFi), this can take hella long time ~6s but Sequoia broke `networksetup -getairportnetwork method` - https://snelson.us/2024/09/determining-a-macs-ssid-like-an-animal/
	[ -z "${currrent_SSID}" ] && currrent_SSID=$(system_profiler -detailLevel basic SPAirPortDataType | awk '/Current Network Information:/ { getline; print substr($0, 13, (length($0) - 13)); exit }')


	SSIDS="${currrent_SSID}"
fi

#if still blank, bail
if [ -z "${SSIDS}" ]; then
	jamflog "[ERROR] No SSID specified, no WiFi connection, exiting."
	exit 1
fi

#finally go through one or more SSIDs
IFS="${delimiter}"
for SSID in ${SSIDS}; do
	setSSIDMode "${SSID}"
	#keep tally for zero/non-zero exit code
	exitCode=$(($? + exitCode))	
done

exit ${exitCode:-0}

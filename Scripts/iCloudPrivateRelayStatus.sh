#!/bin/bash
: <<-LICENSE_BLOCK
iCloud Private Relay Status Checker (20250204) - (https://github.com/brunerd)
Copyright (c) 2025 Joel Bruner (https://github.com/brunerd)
Licensed under the MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
LICENSE_BLOCK

#############
# FUNCTIONS #
#############

#include this self-contained function in your script
function iCloudPrivateRelay()(

	#only for Moneterey and up, 11 and under need not apply
	[ "$(sw_vers -productVersion | cut -d. -f1)" -le 11 ] && return 1
	
	#parent pref domain
	domain="com.apple.networkserviceproxy"
	#key that contains base64 encoded Plist within parent domain
	key="NSPServiceStatusManagerInfo"
	#path within base64 embedded plist, there are multiple PrivacyProxyServiceStatus entries but this one seems primary
	targetPath=':$objects:1:PrivacyProxyServiceStatus'

	#get the top level data from the main domain
	parentData=$(launchctl asuser "$(stat -f %u /dev/console)" sudo -u "$(stat -f %Su /dev/console)" defaults export "${domain}" -)

	#if domain does not exist, fail
	[ -z "${parentData}" ] && return 1

	#export and decode the base64 data as plist XML and look for 
	keyStatusCF=$(/usr/libexec/PlistBuddy -c "print '${targetPath}'" /dev/stdin 2>/dev/null <<< "$(plutil -extract "${key}" xml1 -o - /dev/stdin <<< "${parentData}" | xmllint --xpath "string(//data)" - | base64 --decode | plutil -convert xml1 - -o -)")
	#if no value, fail
	[ -z "${keyStatusCF}" ] && return 1
	
	#if true/1 it is on, 0/off (value is integer not boolean BTW)
	[ "${keyStatusCF}" = "1" ] && return 0 || return 1
)

########
# MAIN #
########

#example - multi-line if/else calling
if iCloudPrivateRelay; then
	echo "iCloud Private Relay is: ON"
else
	echo "iCloud Private Relay is: OFF"
fi

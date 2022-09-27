#!/bin/bash
: <<-LICENSE_BLOCK
Limit IP Tracking Status Checker - (https://github.com/brunerd)
Copyright (c) 2022 Joel Bruner (https://github.com/brunerd)
Other portions: Copyright (c) 2007 Stefan Goessner (goessner.net), Copyright (c) 2020 "jpaquit" (https://github.com/jpaquit), Copyright (c) 2016 Kris Nye, Copyright (c) 2012 Dharmafly, Copyright (c) Kyle Simpson
Licensed under the MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
LICENSE_BLOCK

#############
# FUNCTIONS #
#############

#include this self-contained function in your script
function limitIPTracking()(

	#only for Moneterey and up, 11 and under need not apply
	[ "$(sw_vers -productVersion | cut -d. -f1)" -le 11 ] && return 1

	#Little JSON Tool (ljt) - https://github.com/brunerd/ljt - MIT License
	function ljt () ( #v1.0.8 ljt [query] [file]
	{ set +x; } &> /dev/null; read -r -d '' JSCode <<-'EOT'
	try{var query=decodeURIComponent(escape(arguments[0]));var file=decodeURIComponent(escape(arguments[1]));if(query===".")query="";else if(query[0]==="."&&query[1]==="[")query="$"+query.slice(1);if(query[0]==="/"||query===""){if(/~[^0-1]/g.test(query+" "))throw new SyntaxError("JSON Pointer allows ~0 and ~1 only: "+query);query=query.split("/").slice(1).map(function(f){return"["+JSON.stringify(f.replace(/~1/g,"/").replace(/~0/g,"~"))+"]"}).join("")}else if(query[0]==="$"||query[0]==="."&&query[1]!=="."||query[0]==="["){if(/[^A-Za-z_$\d\.\[\]'"]/.test(query.split("").reverse().join("").replace(/(["'])(.*?)\1(?!\\)/g,"")))throw new Error("Invalid path: "+query);}else query=query.replace("\\.","\udead").split(".").map(function(f){return"["+JSON.stringify(f.replace("\udead","."))+"]"}).join("");if(query[0]==="$")query=query.slice(1);var data=JSON.parse(readFile(file));try{var result=eval("(data)"+query)}catch(e){}}catch(e){printErr(e);quit()}if(result!==undefined)result!==null&&result.constructor===String?print(result):print(JSON.stringify(result,null,2));else printErr("Path not found.")
	EOT
	queryArg="${1}"; fileArg="${2}";jsc=$(find "/System/Library/Frameworks/JavaScriptCore.framework/Versions/Current/" -name 'jsc');[ -z "${jsc}" ] && jsc=$(which jsc);[ -f "${queryArg}" -a -z "${fileArg}" ] && fileArg="${queryArg}" && unset queryArg;if [ -f "${fileArg:=/dev/stdin}" ]; then { errOut=$( { { "${jsc}" -e "${JSCode}" -- "${queryArg}" "${fileArg}"; } 1>&3 ; } 2>&1); } 3>&1;else [ -t '0' ] && echo -e "ljt (v1.0.8) - Little JSON Tool (https://github.com/brunerd/ljt)\nUsage: ljt [query] [filepath]\n  [query] is optional and can be JSON Pointer, canonical JSONPath (with or without leading $), or plutil-style keypath\n  [filepath] is optional, input can also be via file redirection, piped input, here doc, or here strings" >/dev/stderr && exit 0; { errOut=$( { { "${jsc}" -e "${JSCode}" -- "${queryArg}" "/dev/stdin" <<< "$(cat)"; } 1>&3 ; } 2>&1); } 3>&1; fi;if [ -n "${errOut}" ]; then /bin/echo "$errOut" >&2; return 1; fi
	)
		
	#test interface specified or fallback to default interface
	interfaceID=${1:-$(route get 0.0.0.0 2>/dev/null | awk '/interface: / {print $2}')}

	#WIFI: key: PrivacyProxyEnabled, file: /Library/Preferences/com.apple.wifi.known-networks.plist
	#if no error getting WiFi SSID, then we are WiFi
	if networksetup -getairportnetwork "${interfaceID}" &>/dev/null && wifiSSID=$(awk -F ': ' '{print $2}' <<< "$(networksetup -getairportnetwork "${interfaceID}" 2>/dev/null)"); then

		#key name inside plist
		keyName="wifi.network.ssid.${wifiSSID}"

		#oddly this file is only read-able by root
		if [ ! -r /Library/Preferences/com.apple.wifi.known-networks.plist ]; then
			echo "Insufficient preferences to determine WiFi state, run as root" >/dev/stderr
			exit 1
		fi

		#get JSON version, so much easier to get around, convert date and data types to strings
		wifiKnownNetworks_JSON=$(defaults export /Library/Preferences/com.apple.wifi.known-networks.plist - | sed -e 's,<date>,<string>,g' -e 's,</date>,</string>,g' -e 's,<data>,<string>,g' -e 's,</data>,</string>,g' | plutil -convert json -o - -)
		
		#if there is NO entry, then it is active, it is opt-out designed
		PrivacyProxyEnabled=$(ljt "/wifi.network.ssid.${wifiSSID}/PrivacyProxyEnabled" 2>/dev/null <<< "${wifiKnownNetworks_JSON}")
		
		if [ "${PrivacyProxyEnabled}" = "false" ]; then
			return 1
		fi
	#ETHERNET: key: DisablePrivateRelay, file: /Library/Preferences/SystemConfiguration/preferences.plist, 
	else
		#get JSON, easily converts with not data or date types within
		systemConfigPrefsJSON=$(plutil -convert json -o - /Library/Preferences/SystemConfiguration/preferences.plist)
		#get current set UUID
		currentSet=$(echo "${systemConfigPrefsJSON}" | ljt /CurrentSet 2>/dev/null)
		#get value for current default interface of current Location set
		DisablePrivateRelay=$(ljt "${currentSet}"/Network/Interface/${interfaceID}/DisablePrivateRelay  2>/dev/null <<< "${systemConfigPrefsJSON}")

		#if it is TRUE we are Disabled, then we are NOT ON, return fail code
		if [ "${DisablePrivateRelay}" = "1" ]; then
			return 1
		fi
	fi
)

########
# MAIN #
########

if [ ! -r /Library/Preferences/com.apple.wifi.known-networks.plist ]; then
	echo "Insufficient preferences to determine WiFi state, run as root" >/dev/stderr
	exit 1
fi

#use default interface if nothing is specified for argument $1
interface=${1:-$(route get 0.0.0.0 2>/dev/null | awk '/interface: / {print $2}')}

#returns 0 if ON and 1 if OFF, you may supply an interface or it will fall back the the default
limitIPTracking "${interface}" && echo "Limit IP tracking is ON for: ${interface}" || echo "Limit IP tracking is OFF for: ${interface}"

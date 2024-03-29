#!/bin/sh
#getSupportMacOSVersions-ASLS-EA (Extension Attribute)

: <<-LICENSE_BLOCK
Copyright (c) 2022 Joel Bruner
Licensed under the MIT License - Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
LICENSE_BLOCK

function getSupportedMacOSVersions_ASLS()( 
#getSupportedMacOSVersions_ASLS - uses Apple Software Lookup Service to determine compatible macOS versions for the Mac host that runs this
#  Options:
#  [-a] - to see "all" versions including prior point releases, otherwise only newest of each major version shown

	#macOS Monterey 12+ only
	#[ "$(sw_vers -productVersion | cut -d. -f1)" -lt 12 ] && return 1
	if [ "$(sw_vers -productVersion | cut -d. -f1)" -lt 12 ]; then echo "macOS 12+ required" >&2; return 1; fi

	if [ "${1}" = "-a" ]; then
		setName="AssetSets"
	else
		setName="PublicAssetSets"
	fi

	#get Device ID for Apple Silicon or Board ID for Intel
	case "$(arch)" in
		"arm64")
			#NOTE: Output on ARM is Device ID (J314cAP) but on Intel output is Model ID (MacBookPro14,3)
			#uses plutil raw output macOS 12+ only
			myID=$(ioreg -arc IOPlatformExpertDevice -d 1 | plutil -extract 0.IORegistryEntryName raw -o - - 2>/dev/null)
		;;
		"i386")
			#Intel only, Board ID (Mac-551B86E5744E2388)
			#uses plutil raw output macOS 12+ only
			myID=$(ioreg -arc IOPlatformExpertDevice -d 1 | plutil -extract 0.board-id raw -o - - 2>/dev/null | base64 -D)
		;;
	esac	

	#get JSON data from "Apple Software Lookup Service" - https://developer.apple.com/business/documentation/MDM-Protocol-Reference.pdf
	JSONData=$(curl -s https://gdmf.apple.com/v2/pmv)

	#get macOS array count, uses plutil raw output macOS 12+ only
	arrayCount=$(plutil -extract "${setName}.macOS" raw -o - /dev/stdin 2>/dev/null <<< "${JSONData}")

	#look for our device/board ID in each array member and add to list if found
	for ((i=0; i<arrayCount; i++)); do
		#if found by grep in JSON (this is sufficient)
		if grep -q \"${myID}\" <<< "$(plutil -extract "${setName}.macOS.${i}.SupportedDevices" json -o - /dev/stdin 2>/dev/null <<< "${JSONData}")"; then
			#add macOS version to the list
			supportedVersions+="${newline}$(plutil -extract "${setName}.macOS.${i}.ProductVersion" raw -o - /dev/stdin 2>/dev/null <<< "${JSONData}")"
			#only set for the next entry, so no trailing newlines
			newline=$'\n'
		fi
	done

	#echo out the results sorted in descending order (newest on top)
	sort -rV <<< "${supportedVersions}"
)
#echo without quotes to strip newlines
echo "<result>"$(getSupportedMacOSVersions_ASLS | sort -V | cut -d. -f1)"</result>"

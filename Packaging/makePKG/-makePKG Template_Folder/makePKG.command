#!/bin/bash
[ -f /tmp/debug ] && set -x
: <<-LICENSE_BLOCK
makePKG - a simple packager-upper for macOS - Copyright (c) 2021 Joel Bruner (https://github.com/brunerd)
Licensed under the MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
LICENSE_BLOCK

#############
# VARIABLES #
#############

#example: bundle_prefix="com.yourcompany"
bundle_prefix=""

#example: signingID="Your Name (123ABC45D6)"
signingID=""

######################
# COMPUTED VARIABLES #
######################

#where we are and our name
myScriptName=$(basename "$0")
myFolderPath=$(dirname "$0")
myFolderName=$(basename "$myFolderPath")

#replace any spaces in the folder name with sapces (for bundle id name)
myFolderName=${myFolderName// /_}

#build the full bundle prefix
bundle_id="${bundle_prefix}.${myFolderName}"

#place preflight and postflight scripts in here
myFolderPath_scripts="$myFolderPath"/scripts

#recreate the exact folder structure from root in here
myFolderPath_payload="$myFolderPath"/payload

#folder for the output
myFolderPath_build="$myFolderPath"/build

########
# MAIN #
########

#make the build folder if it does not exist
[ ! -d "$myFolderPath_build" ] && mkdir "$myFolderPath_build"

#if we want to date stamp the file use this code: $(/bin/date '+%y.%m.%d')

#if we have some script make sure the execute bit is set
if [ -n "$(ls "${myFolderPath_scripts}" 2>/dev/null)" ]; then
	chmod -R ugo+x "${myFolderPath_scripts}"
fi

#if payload is empty AND scripts not empty
if [ -z "$(ls "$myFolderPath_payload" 2>/dev/null)" ] && [ -n "$(ls "${myFolderPath_scripts}" 2>/dev/null)" ]; then
	echo "Creating Package: No payload, scripts only"
	
	#no payload, scripts only
	[ -z "$signingID" ] && pkgbuild --nopayload --scripts "$myFolderPath_scripts" --identifier="${bundle_id}" --version="1.0" "${myFolderPath_build}/${myFolderName}.pkg"
	[ -n "$signingID" ] && pkgbuild --nopayload --scripts "$myFolderPath_scripts" --identifier="${bundle_id}" --version="1.0" --sign="${signingID}" "${myFolderPath_build}/${myFolderName}.pkg"

#if payload is not empty AND scripts not empty
elif [ -n "$(ls "$myFolderPath_payload")" ] && [ -n "$(ls "$myFolderPath_scripts" 2>/dev/null)" ]; then
	echo "Creating Package: Payload and scripts"
	#payload and scripts
	[ -z "$signingID" ] && pkgbuild --install-location "/" --root "$myFolderPath_payload" --scripts "$myFolderPath_scripts" --identifier="${bundle_id}" --version="1.0" "${myFolderPath_build}/${myFolderName}.pkg"
	[ -n "$signingID" ] && pkgbuild --install-location "/" --root "$myFolderPath_payload" --scripts "$myFolderPath_scripts" --identifier="${bundle_id}" --version="1.0" --sign="${signingID}" "${myFolderPath_build}/${myFolderName}.pkg"
#if payload is not empty AND scripts empty
elif [ -n "$(ls "$myFolderPath_payload")" ] && [ -z "$(ls "$myFolderPath_scripts" 2>/dev/null)" ]; then
	echo "Creating Package: Payload only, no scripts"
	#payload and scripts
	[ -z "$signingID" ] && pkgbuild --install-location "/" --root "$myFolderPath_payload"  --identifier="${bundle_id}" --version="1.0" "${myFolderPath_build}/${myFolderName}.pkg"
	[ -n "$signingID" ] && pkgbuild --install-location "/" --root "$myFolderPath_payload"  --identifier="${bundle_id}" --version="1.0" --sign="${signingID}" "${myFolderPath_build}/${myFolderName}.pkg"
else
	echo "Error: No payload or scripts found!"
fi

exit

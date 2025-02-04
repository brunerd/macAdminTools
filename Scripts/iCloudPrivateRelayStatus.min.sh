#!/bin/bash
: <<-LICENSE_BLOCK
iCloud Private Relay Status Checker (20250204) - (https://github.com/brunerd)
Copyright (c) 2025 Joel Bruner (https://github.com/brunerd)
Licensed under the MIT License
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
LICENSE_BLOCK

#returns 0 (ON) or 1 (OFF)
function iCloudPrivateRelay()([ "$(sw_vers -productVersion | cut -d. -f1)" -le 11 ] && return 1;domain="com.apple.networkserviceproxy";key="NSPServiceStatusManagerInfo";targetPath=':$objects:1:PrivacyProxyServiceStatus';parentData=$(launchctl asuser "$(stat -f %u /dev/console)" sudo -u "$(stat -f %Su /dev/console)" defaults export "${domain}" -);[ -z "${parentData}" ] && return 1;keyStatusCF=$(/usr/libexec/PlistBuddy -c "print '${targetPath}'" /dev/stdin 2>/dev/null <<< "$(plutil -extract "${key}" xml1 -o - /dev/stdin <<< "${parentData}" | xmllint --xpath "string(//data)" - | base64 --decode | plutil -convert xml1 - -o -)");[ -z "${keyStatusCF}" ] && return 1;[ "${keyStatusCF}" = "1" ] && return 0 || return 1)

#example - multi-line if/else calling
if iCloudPrivateRelay; then
	echo "iCloud Private Relay is: ON"
else
	echo "iCloud Private Relay is: OFF"
fi

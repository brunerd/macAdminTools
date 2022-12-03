#!/bin/sh
: <<-LICENSE_BLOCK
getSupportedMacOSVersions-SWU-EA (Extension Attribute) - Copyright (c) 2022 Joel Bruner
Licensed under the MIT License - Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
LICENSE_BLOCK

#getSupportMacOSVersions_SWU - uses softwareupdate to determine compatible macOS versions for the Mac host that runs this
function getSupportedMacOSVersions_SWU()( 
	#get full installers (Big Sur 11+ ONLY) and strip out all other columns
	softwareupdate --list-full-installers | awk -F 'Version: |, Size' '/Title:/{print $2}'
)

#echo without quotes to strip newlines (e.g. "11 12 13")
echo "<result>"$(getSupportedMacOSVersions_SWU | cut -d. -f1 | sort -V | uniq)"</result>"

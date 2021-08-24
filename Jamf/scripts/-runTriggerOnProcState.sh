#!/bin/bash
: <<-LICENSE_BLOCK
runTriggerOnProcState - Copyright (c) 2021 Joel Bruner (https://github.com/brunerd)
Licensed under the MIT License
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
LICENSE_BLOCK

#the process name that will be tested
process="${4}"

#condition to match if process  "IS" or "NOT"* running
condition="${5:-NOT}"

#change IFS to tab and newline
IFS=$'\t\n'
#triggers to run on condition match for process state
argArray=( ${6} ${7} ${8} ${9} ${10} ${11} )

function jamflog {
	local logFile="{$2:-/var/log/jamf.log}"
	#if it exists but we cannot write to the log or it does not exist, unset and tee simply echoes
	[ -e "${logFile}" -a ! -w "${logFile}" ] && unset logFile
	#this will tee to jamf.log in the jamf log format: <Day> <Month> DD HH:MM:SS <Computer Name> ProcessName[PID]: <Message>
	echo "$(date +'%a %b %d %H:%M:%S') ${myComputerName:="$(scutil --get ComputerName)"} ${myName:="$(basename "${0%.*}")"}[${myPID:=$$}]: ${1}" | tee -a "${logFile}" 2>/dev/null
}

########
# MAIN #
########

#ensure we have something for process name 
if [ -z "${4}" ]; then
    jamflog "No process name given, exiting"
    exit 1
fi

#make sure have something, test all parameters
if [ -z "${6}${7}${8}${9}${10}${11}" ]; then
    jamflog "No arguments given, exiting"
    exit 1
fi

#if process exists and condition is for to NOT be running then bail
if pgrep "${process}" &>/dev/null && [ "${condition}" = "NOT" ]; then
	jamflog "Exiting. Condition NOT and process IS running: ${process} ($(pgrep "${process}"))"
	exit
elif ! pgrep "${process}" &>/dev/null && [ "${condition}" = "IS" ]; then
	jamflog "Exiting. Condition IS and process is NOT running: ${process}"
	exit
elif pgrep "${process}" &>/dev/null && [ "${condition}" = "IS" ]; then
	jamflog "Continuing. Condition IS and process IS running: ${process} ($(pgrep "${process}"))"
elif ! pgrep "${process}" &>/dev/null && [ "${condition}" = "NOT" ]; then
	jamflog "Continuing. Condition NOT and process is NOT running: ${process}"
fi

#loop through array, start with array element 0
for (( i=0; i < ${#argArray[@]}; i++ )); do
	#get event item from the array
    item="${argArray[$i]}"

	#skip empty events or those "commented" out code with a #
    if [ "${item:0:1}" == "#" -o -z "${item}" ]; then
		echo "Skipping item ${i}: ${item}"
		continue
    fi
    
    jamflog "Executing: jamf policy -event \"${item}\""
    #send output to null the policy itself will be capturing it's output and logging it
    jamf policy -event "${item}" 2>/dev/null 1>&2
    jamflog "Finished: jamf policy -event \"${item}\", exit code: $?"
done

exit 0

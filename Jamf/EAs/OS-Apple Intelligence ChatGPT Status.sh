#!/bin/sh
#Check Apple Intelligence GenAI status for the console user - An extension attribute and generic function (genAIAssistantSetting)
#Copyright (c) 2024 Joel Bruner (https://github.com/brunerd, https://brunerd.com). Licensed under the MIT License. Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

function genAIAssistantSetting(){
	#get console user
	local consoleUser=$(stat -f %Su /dev/console)
	#if root, get the last console user
	[ "${consoleUser}" = "root" ] && local consoleUser=$(/usr/bin/last -1 -t console | awk '{print $1}')
	
	#run as user within launchd context
	launchctl asuser $(id -u "${consoleUser}") sudo su "${consoleUser}" -c "/usr/bin/defaults read com.apple.siri.generativeassistantsettings isEnabled 2>/dev/null"
	#result is either 0 (Off), 1 (On), or not set
}

value=$(genAIAssistantSetting)

#this is a bit more straightforward it seems, still this system is solid
case "${value}" in
	0) interpretation="Off";;
	1) interpretation="On";;
	'')interpretation="Not Set";;
	*) interpretation="Unknown";;
esac

#usual responses: "On (1)", "Off (0)", or "Not Set ()"
result="${interpretation} (${value})"
echo "<result>${result}</result>"

exit 0

#!/bin/bash
#simpleAlert-AS - Copyright (c) 2023 Joel Bruner (https://github.com/brunerd)
#Licensed under the MIT License

#Simple Applescript alert dialog for Jamf - just a title, a message and an OK button
#Accepts hex (\xnn) and octal (\0nnn) escaped UTF-8 encoded characters (since the default Jamf db character set mangles 4 byte Unicode)
#Use shef to encode your strings/files for use in this script: https://github.com/brunerd/shef

#function to interpret the escapes and fixup characters that can screw up Applescript if unescaped \ and "
function interpretEscapesFixBackslashesAndQuotes()(echo -e "${@}" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')

function jamflog(){
	local logFile="/var/log/jamf.log"
	#if we cannot write to the log or it does not exist, unset and tee simply echoes
	[ ! -w "${logFile}" ] && unset logFile
	#this will tee to jamf.log in the jamf log format: <Day> <Month> DD HH:MM:SS <Computer Name> ProcessName[PID]: <Message>
	echo "$(date +'%a %b %d %H:%M:%S') ${myComputerName:="$(scutil --get ComputerName)"} ${myName:="$(basename "${0}" | sed 's/\..*$//')"}[${myPID:=$$}]: ${1}" | tee -a "${logFile}" 2>/dev/null
}


#process our input then escape for AppleScript
message=$(interpretEscapesFixBackslashesAndQuotes "${4}")
title=$(interpretEscapesFixBackslashesAndQuotes "${5}")
#could be a path or a built-in icon (stop, caution, note)
icon="${6}"
#invoke the system open command with this argument (URL, preference pane, etc...)
open_item="${7}"

#these are the plain icons (Applescript otherwise badges them with the calling app)
case "${icon}" in
	"stop") icon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertStopIcon.icns";;
	"caution") icon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertCautionIcon.icns"
		#previous icon went away in later macOS RIP
		[ ! -f "${icon}" ] && icon="/System/Library/CoreServices/Problem Reporter.app/Contents/Resources/ProblemReporter.icns";;
	"note") icon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertNoteIcon.icns";;
esac

#make string only if path is valid (otherwise dialog fails)
if [ -f "${icon}" ]; then
	withIcon_AS="with icon file (POSIX file \"${icon}\")"
fi

jamflog "Prompting user: $(stat -f %Su /dev/console)"

#prompt the user, giving up and moving on after 1 day (86400 seconds)
/usr/bin/osascript <<-EOF
activate
with timeout of 86400 seconds
	display dialog "${message}" with title "${title}" ${withIcon_AS} buttons {"OK"} default button "OK" giving up after "86400"
end timeout
EOF

if [ -n "${open_item}" ]; then
	jamflog "Opening: ${open_item}"
	open "${open_item}"
fi

exit 0

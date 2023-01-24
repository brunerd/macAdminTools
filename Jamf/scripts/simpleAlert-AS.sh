#!/bin/bash
#simpleAlert-AS - Copyright (c) 2023 Joel Bruner (https://github.com/brunerd)
#Licensed under the MIT License

#Simple Applescript alert dialog for Jamf - just a title, a message and an OK button
#Accepts \x escaped UTF-8 encoded characters (since the default Jamf db character set mangles 4 byte Unicode)
#Use hexencode.sh, also in my github, to encode your strings/files

#function to interpret the escapes and fixup characters that can screw up Applescript if unescaped \ and "
function interpretEscapesFixBackslashesAndQuotes()(echo -e "${@}" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')

#fix up our inputs
message=$(interpretEscapesFixBackslashesAndQuotes "${4}")
title=$(interpretEscapesFixBackslashesAndQuotes "${5}")
#could be a path or a built-in (stop, caution, note)
icon="${6}"

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

/usr/bin/osascript <<-EOF
activate
with timeout of 133200 seconds
	display dialog "${message}" with title "${title}" ${withIcon_AS} buttons {"OK"} default button "OK"
end timeout
EOF

exit 0
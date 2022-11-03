#!/bin/bash
#consoleHasAdobeCCSignIn - Copyright (c) 2022 Joel Bruner - MIT License

function consoleHasAdobeCCSignIn()(
	consoleUser=$(stat -f %Su /dev/console)

	#if root grab the last console user
	if [ "${consoleUser}" = "root" ]; then
		consoleUser=$(/usr/bin/last -1 -t console | awk '{print $1}')
	fi
	
	sudo -u ${consoleUser} sh -c 'ls ~/Library/Application\ Support/Adobe/Creative\ Cloud\ Libraries/LIBS/librarylookupfile &>/dev/null'
	return $?
)

#leverage return value with an if statement
if consoleHasAdobeCCSignIn; then
	result="Signed In"
else
	result="Signed Out"
fi

echo "Adobe CC status ($(stat -f %Su /dev/console)): $result"
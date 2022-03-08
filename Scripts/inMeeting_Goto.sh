#!/bin/sh
#inMeeting_Goto (20220227) Copyright (c) 2022 Joel Bruner (https://github.com/brunerd)
#Licensed under the MIT License

function inMeeting_Goto() {
	#if this process exists, there is a meeting, return 0 (sucess), otherwise 1 (fail)
	pgrep "GoTo Helper \(Plugin\)" &>/dev/null && return 0 || return 1
}

if inMeeting_Goto; then
	echo "In Goto meeting"
	exit 1
else
	echo "Not in Goto meeting"
	exit 0
fi
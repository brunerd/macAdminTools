#!/bin/sh
#inMeeting_Zoom (20220227) Copyright (c) 2022 Joel Bruner (https://github.com/brunerd)
#Licensed under the MIT License

function inMeeting_Zoom {
	#if this process exists, there is a meeting, return 0 (sucess), otherwise 1 (fail)
	pgrep "CptHost" &>/dev/null && return 0 || return 1
}

if inMeeting_Zoom; then
	echo "In Zoom meeting"
else
	echo "Not in Zoom meeting"
fi
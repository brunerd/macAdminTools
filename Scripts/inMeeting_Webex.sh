#!/bin/sh
#inMeeting_Webex (20220227) Copyright (c) 2022 Joel Bruner (https://github.com/brunerd)
#Licensed under the MIT License

function inMeeting_Webex {
	#if this process exists, there is a meeting, return 0 (sucess), otherwise 1 (fail)
	ps auxww | grep -q "[(]WebexAppLauncher)" && return 0 || return 1
}

if inMeeting_Webex; then
	echo "In Zoom meeting... don't be a jerk"
else
	echo "Not Webex in meeting"
fi

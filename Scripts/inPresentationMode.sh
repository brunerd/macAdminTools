#!/bin/sh
#inPresentationMode (20220319) Copyright (c) 2022 Joel Bruner (https://github.com/brunerd)
#with code from Installomator (https://github.com/Installomator/Installomator) Copyright 2020 Armin Briegel, PR 268 by Raptor399 (Patrick Atoon)
#Licensed under the MIT License

function inPresentationMode {
	#Apple Dev Docs: https://developer.apple.com/documentation/iokit/iopmlib_h/iopmassertiontypes
	#ignore assertions without the process in parentheses, any coreaudiod procs, and "Video Wake Lock" is just Chrome playing a Youtube vid in the foreground
	assertingApps=$(/usr/bin/pmset -g assertions | /usr/bin/awk '/NoDisplaySleepAssertion | PreventUserIdleDisplaySleep/ && match($0,/\(.+\)/) && ! /coreaudiod/ && ! /Video\ Wake\ Lock/ {gsub(/^.*\(/,"",$0); gsub(/\).*$/,"",$0); print};')
	[ -n "${assertingApps}" ] && return 0 || return 1
}

if inPresentationMode; then
	echo "In presentation mode... don't be a jerk"
else
	echo "Not in presentation mode..."
fi

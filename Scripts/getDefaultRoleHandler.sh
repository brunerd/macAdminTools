#!/bin/sh
: <<-LICENSE_BLOCK
Get Default Role Handler - (https://github.com/brunerd)
Copyright (c) 2022 Joel Bruner (https://github.com/brunerd)
Licensed under the MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
LICENSE_BLOCK

#############
# FUNCTIONS #
#############

#use this self-contained function in your script to detect the default role handle
function getDefaultRoleHandler() (
	#provide a URL scheme like: http, https, ftp, etc...
	URLScheme=${1}
	
	#fail quickly
	if [ -z "${URLScheme}" ]; then
		>/dev/stderr echo "No URL scheme specified"
		return 1
	fi

	#Little JSON Tool (ljt) v1.0.7 - https://github.com/brunerd/ljt - MIT License
	function ljt () ( 
	[ -n "${-//[^x]/}" ] && set +x; read -r -d '' JSCode <<-'EOT'
	try{var query=decodeURIComponent(escape(arguments[0])),file=decodeURIComponent(escape(arguments[1]));if("/"===query[0]||""===query){if(/~[^0-1]/g.test(query+" "))throw new SyntaxError("JSON Pointer allows ~0 and ~1 only: "+query);query=query.split("/").slice(1).map(function(a){return"["+JSON.stringify(a.replace(/~1/g,"/").replace(/~0/g,"~"))+"]"}).join("")}else if("$"===query[0]||"."===query[0]||"["===query[0]){if(/[^A-Za-z_$\d\.\[\]'"]/.test(query.split("").reverse().join("").replace(/(["'])(.*?)\1(?!\\)/g,"")))throw Error("Invalid path: "+query);}else query=query.replace("\\.","\udead").split(".").map(function(a){return"["+JSON.stringify(a.replace("\udead","."))+"]"}).join("");"$"===query[0]&&(query=query.slice(1,query.length));var data=JSON.parse(readFile(file));try{var result=eval("(data)"+query)}catch(a){}}catch(a){printErr(a),quit()}void 0!==result?null!==result&&result.constructor===String?print(result):print(JSON.stringify(result,null,2)):printErr("Path not found.");
	EOT
	queryArg="${1}"; fileArg="${2}";jsc=$(find "/System/Library/Frameworks/JavaScriptCore.framework/Versions/Current/" -name 'jsc');[ -z "${jsc}" ] && jsc=$(which jsc);[ -f "${queryArg}" -a -z "${fileArg}" ] && fileArg="${queryArg}" && unset queryArg;if [ -f "${fileArg:=/dev/stdin}" ]; then { errOut=$( { { "${jsc}" -e "${JSCode}" -- "${queryArg}" "${fileArg}"; } 1>&3 ; } 2>&1); } 3>&1;else [ -t '0' ] && echo -e "ljt (v1.0.7) - Little JSON Tool (https://github.com/brunerd/ljt)\nUsage: ljt [query] [filepath]\n  [query] is optional and can be JSON Pointer, canonical JSONPath (with or without leading $), or plutil-style keypath\n  [filepath] is optional, input can also be via file redirection, piped input, here doc, or here strings" >/dev/stderr && exit 0; { errOut=$( { { "${jsc}" -e "${JSCode}" -- "${queryArg}" "/dev/stdin" <<< "$(cat)"; } 1>&3 ; } 2>&1); } 3>&1; fi;if [ -n "${errOut}" ]; then /bin/echo "$errOut" >&2; return 1; fi
	)

	#in case being run as root get the current console user
	consoleUserHomeFolder=$(sudo -u "$(stat -f %Su /dev/console)" sh -c 'echo ~')
	#get the LaunchServices LSHandlers JSON of the console user
	launchServicesJSON=$(launchctl asuser "$(stat -f %u /dev/console)" sudo -u "$(stat -f %Su /dev/console)" plutil -extract LSHandlers json -o - "${consoleUserHomeFolder}"/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist)

	#loop through JSON and try and find matching URLScheme within
	for ((i=0;;i++)); do
		#if we are at the END of the array or nothing exists bail
		if ! ljt "/$i" <<< "${launchServicesJSON}" &>/dev/null; then
			return 1
		elif [ "$(ljt "/$i/LSHandlerURLScheme" <<< "${launchServicesJSON}" 2>/dev/null)" = "$URLScheme" ]; then
			#run query, print result, errors go to /dev/null, if ljt fails to find something return non-zero
			if ! ljt "/$i/LSHandlerRoleAll" <<< "${launchServicesJSON}" 2>/dev/null; then
				#error
				return 1
			else
				#success
				return 0
			fi
		fi
	done
	
	#if we are here, we did NOT find a match
	return 1	
)

########
# MAIN #
########

getDefaultRoleHandler "$@"

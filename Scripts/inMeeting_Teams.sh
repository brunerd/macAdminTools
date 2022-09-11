#!/bin/bash
#inMeeting_Teams (202209210) Copyright (c) 2022 Joel Bruner (https://github.com/brunerd)
#Licensed under the MIT License

function inMeeting_Teams ()(

	#v1.0.7
	function ljt () ( 
	{ set +x; } &> /dev/null; read -r -d '' JSCode <<-'EOT'
	try{var query=decodeURIComponent(escape(arguments[0])),file=decodeURIComponent(escape(arguments[1]));if("/"===query[0]||""===query){if(/~[^0-1]/g.test(query+" "))throw new SyntaxError("JSON Pointer allows ~0 and ~1 only: "+query);query=query.split("/").slice(1).map(function(a){return"["+JSON.stringify(a.replace(/~1/g,"/").replace(/~0/g,"~"))+"]"}).join("")}else if("$"===query[0]||"."===query[0]||"["===query[0]){if(/[^A-Za-z_$\d\.\[\]'"]/.test(query.split("").reverse().join("").replace(/(["'])(.*?)\1(?!\\)/g,"")))throw Error("Invalid path: "+query);}else query=query.replace("\\.","\udead").split(".").map(function(a){return"["+JSON.stringify(a.replace("\udead","."))+"]"}).join("");"$"===query[0]&&(query=query.slice(1,query.length));var data=JSON.parse(readFile(file));try{var result=eval("(data)"+query)}catch(a){}}catch(a){printErr(a),quit()}void 0!==result?null!==result&&result.constructor===String?print(result):print(JSON.stringify(result,null,2)):printErr("Path not found.");
	EOT
	queryArg="${1}"; fileArg="${2}";jsc=$(find "/System/Library/Frameworks/JavaScriptCore.framework/Versions/Current/" -name 'jsc');[ -z "${jsc}" ] && jsc=$(which jsc);[ -f "${queryArg}" -a -z "${fileArg}" ] && fileArg="${queryArg}" && unset queryArg;if [ -f "${fileArg:=/dev/stdin}" ]; then { errOut=$( { { "${jsc}" -e "${JSCode}" -- "${queryArg}" "${fileArg}"; } 1>&3 ; } 2>&1); } 3>&1;else [ -t '0' ] && echo -e "ljt (v1.0.7) - Little JSON Tool (https://github.com/brunerd/ljt)\nUsage: ljt [query] [filepath]\n  [query] is optional and can be JSON Pointer, canonical JSONPath (with or without leading $), or plutil-style keypath\n  [filepath] is optional, input can also be via file redirection, piped input, here doc, or here strings" >/dev/stderr && exit 0; { errOut=$( { { "${jsc}" -e "${JSCode}" -- "${queryArg}" "/dev/stdin" <<< "$(cat)"; } 1>&3 ; } 2>&1); } 3>&1; fi;if [ -n "${errOut}" ]; then /bin/echo "$errOut" >&2; return 1; fi )

	consoleUser=$(stat -f %Su /dev/console)
	consoleUserHomeFolder=$(dscl . -read /Users/"${consoleUser}" NFSHomeDirectory | awk -F ': ' '{print $2}')
	storageJSON_path="${consoleUserHomeFolder}/Library/Application Support/Microsoft/Teams/storage.json"
	
	#no file, no meeting
	[ ! -f "${storageJSON_path}" ] && return 1

	#get both states
	appState=$(ljt /appStates/states "${storageJSON_path}" | tr , $'\n' | tail -n 1)
	webappState=$(ljt /webAppStates/states "${storageJSON_path}"| tr , $'\n' | tail -n 1)
	
	#determine app state
	if [ "${appState}" = "InCall" ]	|| [ "${webAppState}" = "InCall" ]; then
		return 0
	else
		return 1
	fi
)


if inMeeting_Teams; then
	echo "In Teams Meeting... don't be a jerk"
else
	echo "Not in Teams Meeting"
fi

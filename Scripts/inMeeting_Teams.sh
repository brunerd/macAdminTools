#!/bin/bash
#inMeeting_Teams (20220227) Copyright (c) 2022 Joel Bruner (https://github.com/brunerd)
#Licensed under the MIT License

function inMeeting_Teams ()(

	function ljt () ( #v1.0.3
		[ -n "${-//[^x]/}" ] && set +x; read -r -d '' JSCode <<-'EOT'
		try {var query=decodeURIComponent(escape(arguments[0]));var file=decodeURIComponent(escape(arguments[1]));if (query[0]==='/'){ query = query.split('/').slice(1).map(function (f){return "["+JSON.stringify(f)+"]"}).join('')}if(/[^A-Za-z_$\d\.\[\]'"]/.test(query.split('').reverse().join('').replace(/(["'])(.*?)\1(?!\\)/g, ""))){throw new Error("Invalid path: "+ query)};if(query[0]==="$"){query=query.slice(1,query.length)};var data=JSON.parse(readFile(file));var result=eval("(data)"+query)}catch(e){printErr(e);quit()};if(result !==undefined){result!==null&&result.constructor===String?print(result): print(JSON.stringify(result,null,2))}else{printErr("Node not found.")}
		EOT
		queryArg="${1}"; fileArg="${2}";jsc=$(find "/System/Library/Frameworks/JavaScriptCore.framework/Versions/Current/" -name 'jsc');[ -z "${jsc}" ] && jsc=$(which jsc);[ -f "${queryArg}" -a -z "${fileArg}" ] && fileArg="${queryArg}" && unset queryArg;if [ -f "${fileArg:=/dev/stdin}" ]; then { errOut=$( { { "${jsc}" -e "${JSCode}" -- "${queryArg}" "${fileArg}"; } 1>&3 ; } 2>&1); } 3>&1;else { errOut=$( { { "${jsc}" -e "${JSCode}" -- "${queryArg}" "/dev/stdin" <<< "$(cat)"; } 1>&3 ; } 2>&1); } 3>&1; fi;if [ -n "${errOut}" ]; then /bin/echo "$errOut" >&2; return 1; fi
	)

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
	echo "In Teams Meeting"
else
	echo "Not in Teams Meeting"
fi

#!/bin/bash
#CVELookup.sh - look up CVE info (in a file, URL, or list of CVEs) from NVD and output in CSV format
#set -x

: <<-LICENSE_BLOCK
CVELookup.sh - (https://github.com/brunerd) Copyright (c) 2024 Joel Bruner (https://github.com/brunerd). Licensed under the MIT License. Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
LICENSE_BLOCK

#Usage: CVELookup.sh [filepath/URL/text/-]
#URL - CVEs will be extracted from HTML
#filepath/text - text/file contents DO NOT need to be formatted, CVEs are extracted with grep
#- - dash indicates input from stdin, same behavior as others
 
#############
# VARIABLES #
#############

#can be file/URL/text/-
argument1="${1}"

#allows faster lookups without throttling (usually), see: https://nvd.nist.gov/developers/request-an-api-key
apiKey=""

#without API key must slow queries to avoid 403 denial, YMMV on timing
delaySeconds="10"

#URL and parameter name from: https://nvd.nist.gov/developers/vulnerabilities
lookupURL="https://services.nvd.nist.gov/rest/json/cves/2.0"
lookupParamName="cveId"

#############
# FUNCTIONS #
#############

#jq is only on Sequoia and up, ljt helps us out
: <<-LICENSE_BLOCK
ljt.min - Little JSON Tool (https://github.com/brunerd/ljt) Copyright (c) 2022 Joel Bruner (https://github.com/brunerd). Licensed under the MIT License. Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
LICENSE_BLOCK
function ljt () ( #v1.0.8 ljt [query] [file]
{ set +x; } &> /dev/null; read -r -d '' JSCode <<-'EOT'
try{var query=decodeURIComponent(escape(arguments[0]));var file=decodeURIComponent(escape(arguments[1]));if(query===".")query="";else if(query[0]==="."&&query[1]==="[")query="$"+query.slice(1);if(query[0]==="/"||query===""){if(/~[^0-1]/g.test(query+" "))throw new SyntaxError("JSON Pointer allows ~0 and ~1 only: "+query);query=query.split("/").slice(1).map(function(f){return"["+JSON.stringify(f.replace(/~1/g,"/").replace(/~0/g,"~"))+"]"}).join("")}else if(query[0]==="$"||query[0]==="."&&query[1]!=="."||query[0]==="["){if(/[^A-Za-z_$\d\.\[\]'"]/.test(query.split("").reverse().join("").replace(/(["'])(.*?)\1(?!\\)/g,"")))throw new Error("Invalid path: "+query);}else query=query.replace("\\.","\udead").split(".").map(function(f){return"["+JSON.stringify(f.replace("\udead","."))+"]"}).join("");if(query[0]==="$")query=query.slice(1);var data=JSON.parse(readFile(file));try{var result=eval("(data)"+query)}catch(e){}}catch(e){printErr(e);quit()}if(result!==undefined)result!==null&&result.constructor===String?print(result):print(JSON.stringify(result,null,2));else printErr("Path not found.")
EOT
queryArg="${1}"; fileArg="${2}";jsc=$(find "/System/Library/Frameworks/JavaScriptCore.framework/Versions/Current/" -name 'jsc');[ -z "${jsc}" ] && jsc=$(which jsc);[ -f "${queryArg}" -a -z "${fileArg}" ] && fileArg="${queryArg}" && unset queryArg;if [ -f "${fileArg:=/dev/stdin}" ]; then { errOut=$( { { "${jsc}" -e "${JSCode}" -- "${queryArg}" "${fileArg}"; } 1>&3 ; } 2>&1); } 3>&1;else [ -t '0' ] && echo -e "ljt (v1.0.8) - Little JSON Tool (https://github.com/brunerd/ljt)\nUsage: ljt [query] [filepath]\n  [query] is optional and can be JSON Pointer, canonical JSONPath (with or without leading $), or plutil-style keypath\n  [filepath] is optional, input can also be via file redirection, piped input, here doc, or here strings" >/dev/stderr && exit 0; { errOut=$( { { "${jsc}" -e "${JSCode}" -- "${queryArg}" "/dev/stdin" <<< "$(cat)"; } 1>&3 ; } 2>&1); } 3>&1; fi;if [ -n "${errOut}" ]; then /bin/echo "$errOut" >&2; return 1; fi
)

#extract CVE-xxxx-xxxx from given input, sort and uniq, then normalize to upper case
function getCVEMatches(){
	local input="${1}"
	grep -a -o -E "(cve|CVE)-\d{4}-\d{4,}" <<< "${input}" | sort | uniq | tr '[[:lower:]]' '[[:upper:]]'
}

########
# MAIN #
########

#hardcode always wins
if [ "${argument1}" = "-" ]; then
	echo "Enter CVE IDs, blank line to end: " >&2
	#sed will keep accepting input until it hits a blank line
	rawData=$(sed '/^$/q')
#if its a file use that
elif [ -f "${argument1}" ]; then
	rawData=$(< "${argument1}")
#if URL get data
elif [ "${argument1:0:4}" = "http" ]; then
	rawData=$(curl -s "${argument1}")
#may be a list of CVEs
elif [ -n "${argument1}" ]; then
	rawData="${argument1}"
else
	echo "Please specify a file, URL, \"-\" for stdin or argument containing CVE(s)"
	exit 1
fi

#use grep to extract all CVEs from ASCII text/html/whatever, all matches newline delimited
CVE_IDs=$(getCVEMatches "${rawData}")

if [ -z "${CVE_IDs}" ]; then
	echo "No CVEs found in file/URL/input, exiting" >&2
	exit 1
elif [ -z "${apiKey}" ]; then
	echo "No API Key, gating to one request every ${delaySeconds} seconds" >&2
fi

#print header
echo "CVE,Base Score,Vector,Base Severity,Impact Score,Exploitability Score,Description"

#go get those CVE details
IFS=$'\n'
for CVE_ID in $CVE_IDs; do
	#get JSON plus HTTP status code on last line
	curlResponse=$(curl -q -s -w "\\n%{http_code}" -H "Accept: application/json" -H "apiKey:${apiKey}" "${lookupURL}/?${lookupParamName}=${CVE_ID}")
	#trim last line to get JSON
	CVE_JSON=$(sed '$d' <<< "${curlResponse}")
	#get last line (http_code) 
	HTTPCODE=$(tail -n 1 <<< "${curlResponse}")	
	
	#fail loudly and continue if not 200 (API related error (403) or unknown CVE (404) probably)
	if [ "${HTTPCODE}" != 200 ]; then
		echo "${CVE_ID},HTTP CODE $HTTPCODE"
		continue
	fi
	
	#get various bits from JSON
	baseScore=$(ljt '$.vulnerabilities[0].cve.metrics.cvssMetricV31[0].cvssData.baseScore' <<< "${CVE_JSON}" 2>/dev/null)
	vectorString=$(ljt '$.vulnerabilities[0].cve.metrics.cvssMetricV31[0].cvssData.vectorString' <<< "${CVE_JSON}" 2>/dev/null)
	baseSeverity=$(ljt '$.vulnerabilities[0].cve.metrics.cvssMetricV31[0].cvssData.baseSeverity' <<< "${CVE_JSON}" 2>/dev/null)
	impactScore=$(ljt '$.vulnerabilities[0].cve.metrics.cvssMetricV31[0].impactScore' <<< "${CVE_JSON}" 2>/dev/null)
	exploitabilityScore=$(ljt '$.vulnerabilities[0].cve.metrics.cvssMetricV31[0].exploitabilityScore' <<< "${CVE_JSON}" 2>/dev/null)
	description=$(ljt '$.vulnerabilities[0].cve.descriptions[0].value' 2>/dev/null <<< "${CVE_JSON}" | tr $'\n' ' ' | sed -e $'s/^[ \t]*//g' -e $'s/[ \t]*$//g')
	echo "${CVE_ID},${baseScore},${vectorString},${baseSeverity},${impactScore},${exploitabilityScore},\"${description}\""

	#without API key must rate limit to guard against denied requests
	[ -z "${apiKey}" ] && sleep "${delaySeconds}"
done

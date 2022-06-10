#!/bin/bash
: <<-LICENSE_BLOCK
setAutoLogin.jamf (20220610) - Copyright (c) 2021 Joel Bruner (https://github.com/brunerd)
Licensed under the MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
LICENSE_BLOCK

#############
# VARIABLES #
#############

#JAMF script parameters are shifted +3
#provide a username, if blank will disable autologin
USERNAME="${4}"

#this can be blank if that is the password, it will be verified
PW="${5}"

#############
# FUNCTIONS #
#############

function jamflog {
	local logFile="${2:-/var/log/jamf.log}"
	#if we cannot write to the log or it does not exist, unset and tee simply echoes
	[ ! -w "${logFile}" ] && unset logFile
	#this will tee to jamf.log in the jamf log format: <Day> <Month> DD HH:MM:SS <Computer Name> ProcessName[PID]: <Message>
	echo "$(date +'%a %b %d %H:%M:%S') ${myComputerName:="$(scutil --get ComputerName)"} ${myName:="$(basename "${0}" | sed 's/\..*$//')"}[${myPID:=$$}]: ${1}" | tee -a "${logFile}" 2>/dev/null
}

#given a string creates data for /etc/kcpassword
function kcpasswordEncode () (

	#ascii string
	thisString="${1}"

	#macOS cipher hex ascii representation array
	cipherHex_array=( 7D 89 52 23 D2 BC DD EA A3 B9 1F )

	#converted to hex representation with spaces
	thisStringHex_array=( $(echo -n "${thisString}" | xxd -p -u | sed 's/../& /g') )

	#get padding by subtraction if under 12 
	if [ "${#thisStringHex_array[@]}" -lt 12  ]; then
		padding=$(( 12 -  ${#thisStringHex_array[@]} ))
	#get padding by subtracting remainder of modulo 12 if over 12 
	elif [ "$(( ${#thisStringHex_array[@]} % 12 ))" -ne 0  ]; then
		padding=$(( (12 - ${#thisStringHex_array[@]} % 12) ))
	#otherwise even multiples of 12 still need 12 padding
	else
		padding=12
	fi	

	#cycle through each element of the array + padding
	for ((i=0; i < $(( ${#thisStringHex_array[@]} + ${padding})); i++)); do
		#use modulus to loop through the cipher array elements
		charHex_cipher=${cipherHex_array[$(( $i % 11 ))]}

		#get the current hex representation element
		charHex=${thisStringHex_array[$i]}
	
		#use $(( shell Aritmethic )) to ^ XOR the two 0x## values (extra padding is 0x00) 
		#take decimal value and printf convert to two char hex value
		#use xxd to convert hex to actual value and send to stdout (to avoid NULL issue in bash strings)
		printf "%02X" "$(( 0x${charHex_cipher} ^ 0x${charHex:-00} ))" | xxd -r -p > /dev/stdout
	done
)

########
# MAIN #
########

#quit if not root
if [ "${UID}" != 0 ]; then
	jamflog "Please run as root, exiting."
	exit 1
fi

#if we have a USERNAME
if [ -n "${USERNAME}" ]; then 

	#check user
	if ! id "${USERNAME}" &> /dev/null; then
		jamflog "User '${USERNAME}' not found, exiting."
		exit 1
	fi

	if ! /usr/bin/dscl /Search -authonly "${USERNAME}" "${PW}" &> /dev/null; then
		jamflog "Invalid password for '${USERNAME}', exiting."
		exit 1
	fi

	#encode password and write directly to file 
	kcpasswordEncode "${PW}" > /etc/kcpassword

	#ensure ownership and permissions (600)
	chown root:wheel /etc/kcpassword
	chmod u=rw,go= /etc/kcpassword

	#turn on auto login
	/usr/bin/defaults write /Library/Preferences/com.apple.loginwindow autoLoginUser -string "${USERNAME}"

	jamflog "Auto login enabled for '${USERNAME}'"
#if not USERNAME turn OFF
else
	[ -f /etc/kcpassword ] && rm -f /etc/kcpassword
	/usr/bin/defaults delete /Library/Preferences/com.apple.loginwindow autoLoginUser &> /dev/null
	jamflog "Auto login disabled"
fi

exit 0

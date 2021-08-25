#!/bin/bash
: <<-LICENSE_BLOCK
setAutoLogin - Copyright (c) 2021 Joel Bruner (https://github.com/brunerd)
Licensed under the MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
LICENSE_BLOCK

#############
# VARIABLES #
#############

#this can be blank if that is the password, it will be verified
USERNAME="${1}"

#this can be blank if that is the password
PW="${2}"

#############
# FUNCTIONS #
#############

#given a string creates data for /etc/kcpassword
function kcpasswordEncode {

	#ascii string
	local thisString="${1}"
	local i

	#if there is string data
	if [ -n "${thisString}" ]; then
		#converted to hex representation with spaces
		local thisStringHex_array=( $(echo -n "${thisString}" | xxd -p -u | sed 's/../& /g') )

		#macOS cipher hex ascii representation array
		local cipherHex_array=( 7D 89 52 23 D2 BC DD EA A3 B9 1F )

		#cycle through each element of the array
		for ((i=0; i < ${#thisStringHex_array[@]}; i++)); do
			#use modulus to loop through the cipher array elements
			local charHex_cipher=${cipherHex_array[$(( $i % 10 ))]}

			#get the current hex representation element
			local charHex=${thisStringHex_array[$i]}
		
			#use $(( shell Aritmethic )) to ^ xor the two 0x-prepended hex values to decimal (ugh)
			#then printf to convert to two char hex value
			#use xxd to encode to actual value and append to the encodedString variable
			local encodedString+=$(printf "%X" "$(( 0x${charHex_cipher} ^ 0x${charHex} ))" | xxd -r -p)
		done

		#under 12 get padding by subtraction
		if [ "${#thisStringHex_array[@]}" -lt 12  ]; then
			local padding=$(( 12 -  ${#thisStringHex_array[@]} ))
		#over 12 get padding by subtracting remainder of modulo 12
		elif [ "$(( ${#thisStringHex_array[@]} % 12 ))" -ne 0  ]; then
			local padding=$(( (12 - ${#thisStringHex_array[@]} % 12) ))
		#no padding needed
		else
			local padding=0
		fi
		
		
		#pad the end with multiples of 12
		for ((i=0; i < ${padding}; i++)); do
			local encodedString+=$(xxd -r -p <<< "01")
		done

	#an empty string encodes differently
	else	
		#static hex for an empty password as written by macOS
		local emptyStringHex_array=( 7D EE 94 4A A1 ED 22 A0 4F 90 D2 C7 )

		for ((i=0; i < ${#emptyStringHex_array[@]}; i++)); do
			#use printf to xor the two, xxd to encode and append to the encodedString variable
			local encodedString+=$(printf "%X" "0x${emptyStringHex_array[i]}" | xxd -r -p)
		done
	fi

	#return the string without a newline
	echo -n "${encodedString}"
}

########
# MAIN #
########

#quit if not root
if [ "${UID}" != 0 ]; then
	echo "Please run as root, exiting."
	exit 1
fi

#if we have a USERNAME
if [ -n "${USERNAME}" ]; then 

	#check user
	if ! id "${USERNAME}" &> /dev/null; then
		echo "User '${USERNAME}' not found, exiting."
		exit 1
	fi

	if ! /usr/bin/dscl /Search -authonly "${USERNAME}" "${PW}" &> /dev/null; then
		echo "Invalid password for '${USERNAME}', exiting."
		exit 1
	fi

	#encode password and write file 
	kcpasswordEncode "${PW}" > /etc/kcpassword

	#ensure ownership and permissions (600)
	chown root:wheel /etc/kcpassword
	chmod u=rw,go= /etc/kcpassword

	#turn on auto login
	/usr/bin/defaults write /Library/Preferences/com.apple.loginwindow autoLoginUser -string "${USERNAME}"

	echo "Auto login enabled for '${USERNAME}'"
#if not USERNAME turn OFF
else
	[ -f /etc/kcpassword ] && rm -f /etc/kcpassword
	/usr/bin/defaults delete /Library/Preferences/com.apple.loginwindow autoLoginUser &> /dev/null
	echo "Auto login disabled"
fi

exit 0

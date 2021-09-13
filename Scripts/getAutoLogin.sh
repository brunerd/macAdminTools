#!/bin/bash
: <<-LICENSE_BLOCK
getAutoLogin (20210913) - Copyright (c) 2021 Joel Bruner (https://github.com/brunerd)
Licensed under the MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
LICENSE_BLOCK


#############
# FUNCTIONS #
#############

#given a string from /etc/kcpassword will XOR it back and truncate padding
function kcpasswordDecode {

	#ascii string
	local thisString="${1}"
	local i

	#macOS cipher hex ascii representation array
	local cipherHex_array=( 7D 89 52 23 D2 BC DD EA A3 B9 1F )

	#converted to hex representation with spaces
	local thisStringHex_array=( $(echo -n "${thisString}" | xxd -p -u | sed 's/../& /g') )

	#cycle through each element of the array + padding
	for ((i=0; i < ${#thisStringHex_array[@]}; i++)); do
		#use modulus to loop through the cipher array elements
		local charHex_cipher=${cipherHex_array[$(( $i % 11 ))]}

		#get the current hex representation element
		local charHex=${thisStringHex_array[$i]}

		#if cipher and character are NOT the same (they also XOR to 00)
		if [ "${charHex}" != "${charHex_cipher}" ]; then		
			local encodedString+=$(printf "%02X" "$(( 0x${charHex_cipher} ^ 0x${charHex:-00} ))" | xxd -r -p)
		else
			break
		fi
	done

	#return the string without a newline
	echo -n "${encodedString}"
}

########
# MAIN #
########

if [ "${UID}" != "0" ]; then
	echo "Please run as root."
	exit 1
fi

#get on auto user
autoLoginUser=$(/usr/bin/defaults read /Library/Preferences/com.apple.loginwindow autoLoginUser -string "${USERNAME}" 2>/dev/null)

if [ -z "${autoLoginUser}" ]; then
	echo "Auto login disabled"
else
	echo "Auto login user: ${autoLoginUser}"
	echo "Password: $(kcpasswordDecode "$(</etc/kcpassword)")"
fi

exit 0

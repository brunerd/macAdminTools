#!/bin/bash
: <<-LICENSE_BLOCK
getAutoLogin (20220729) - Copyright (c) 2021 Joel Bruner (https://github.com/brunerd)
Licensed under the MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
LICENSE_BLOCK


#############
# FUNCTIONS #
#############

#will XOR it back and truncate padding
function kcpasswordDecode() (
	filepath="${1}"
	#no file
	if [ -z "${filepath}" ]; then
		[ ! -t '0' ] && echo "Redirected input no longer supported" >/dev/stderr
		echo "Please specify a file path" >/dev/stderr
		exit 1
	#bad file
	elif [ ! -f "${filepath}" ]; then
		echo "$(basename "$0"): ${filepath}: No such file" >/dev/stderr
		exit 1
	#file
	else
		#test for type of data
		case "$(file -b "${filepath}")" in
			#in some cases the kcpassword may be a hex representation in ASCII (10.10+)
			"ASCII text")
				#just space out the ASCII data into 2 byte couplets
				thisStringHex_array=( $(sed 's/../& /g' "${filepath}") )
				;;
			#otherwise treat as binary data
			*)
				#convert to hex representation with spaces
				thisStringHex_array=( $(xxd -p -u "${filepath}" | sed 's/../& /g') )
			;;
		esac
	fi

	#macOS cipher hex ascii representation array
	cipherHex_array=( 7D 89 52 23 D2 BC DD EA A3 B9 1F )	

	for ((i=0; i < ${#thisStringHex_array[@]}; i++)); do
		#use modulus to loop through the cipher array elements
		charHex_cipher=${cipherHex_array[$(( $i % 11 ))]}

		#get the current hex representation element
		charHex=${thisStringHex_array[$i]}
	
		#use $(( shell Aritmethic )) to ^ XOR the two 0x## values (extra padding is 0x00) 
		#take decimal value and printf convert to two char hex value
		#use xxd to convert hex to ascii representation
		decodedCharacter=$(printf "%02X" "$((0x${charHex_cipher} ^ 0x${charHex:-00}))")		

		if [[ "${decodedCharacter}" = "00" ]]; then
			break
		else
			printf "%02X" "$(( 0x${charHex_cipher} ^ 0x${charHex:-00} ))" | xxd -r -p > /dev/stdout
		fi
	done
)

########
# MAIN #
########

if [ "${UID}" != "0" ]; then
	echo "Please run as root."
	exit 1
fi

#get on auto user
autoLoginUser=$(/usr/bin/defaults read /Library/Preferences/com.apple.loginwindow autoLoginUser -string "${USERNAME}" 2>/dev/null)

#echo it out or fall back to <NOT_SET>
echo "Auto login user: ${autoLoginUser:-<NOT_SET>}"

if [ -f /etc/kcpassword ]; then
	echo "Password: $(kcpasswordDecode /etc/kcpassword)"
else
	echo "Password: <NOT_SET>"
fi

exit 0

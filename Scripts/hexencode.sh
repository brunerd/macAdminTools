#!/bin/bash
#!/bin/zsh
#works in either
: <<-LICENSE_BLOCK
hexencode - Copyright (c) 2023 Joel Bruner (https://github.com/brunerd/macAdminTools)
Licensed under the MIT License
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
LICENSE_BLOCK

# hexencode [-a] [-e] ["<string>"]|[< <filepath>]|[<<< \"here string\"]|[<<HERDOC]
# \x escapes a string, by default ONLY encodes control characters < 0x20 and multi-byte Unicode > 0x7F
# Input: takes string as an argument or will use file redirection (<), "here string" (<<<), or "here doc" (<<)
# Output options: [-a] encode all characters, [-e] escape format chars in ANSI C-style \b \f \n \r \t \v (overrides -a)
# The output can be reconstituted using echo -e "<string>" or echo $'<string>' (<-although watch out for unescaped single quotes)
# Example: echo -e "\xF0\x9F\xA4\x93" or echo $'\xF0\x9F\xA4\x93' will produce U+1F913 "smiling face with glasses"

function hexencode()(
	while getopts ":ahe" option; do
		case "${option}" in
			'a')flag_a=1;;
			'e')flag_e=1;;
			'h')echo -e "hexencode [-a] [-e] [\"<string>\"]|[< <filepath>]|[<<< \"here string\"]|[<<HERDOC]\nOptions:\n\t-a encode ALL characters\n\t-e escape format chars (overriding -a) in C-style: \\\\b \\\\f \\\\n \\\\r \\\\t \\\\v"
		esac
	done
	#shift if we had args so $1 is our string
	[ $OPTIND -ge 2 ] && shift $((OPTIND-1))

	#if no string for argument 
	if [ -z "${1}" ]; then 
		#if no redirected input either thenreturn
		#otherwise set $1 to contents of redirected input
		[ -t '0' ] && return || set -- "$(cat)"
	fi

	#get length (use -m for multibyte Unicode chars NOT -c byte count)
	length=$(($(echo -n "${1}" | wc -m)))

	#go through each character
	for (( i=0; i<${length}; i++ )); do	
		#encode whitespace characters (or not)
		case "${1:$i:1}" in
			#whitespace may be printed C-style escaped or passed through unaltered
			$'\b')if ((${flag_e}));then echo -n '\b';continue; elif ! ((${flag_a}));then echo -n $'\b';continue;fi ;;
			$'\f')if ((${flag_e}));then echo -n '\f';continue; elif ! ((${flag_a}));then echo -n $'\f';continue;fi ;;
			$'\n')if ((${flag_e}));then echo -n '\n';continue; elif ! ((${flag_a}));then echo -n $'\n';continue;fi ;;
			$'\r')if ((${flag_e}));then echo -n '\r';continue; elif ! ((${flag_a}));then echo -n $'\r';continue;fi ;;
			$'\t')if ((${flag_e}));then echo -n '\t';continue; elif ! ((${flag_a}));then echo -n $'\t';continue;fi ;;
			$'\v')if ((${flag_e}));then echo -n '\v';continue; elif ! ((${flag_a}));then echo -n $'\v';continue;fi ;;
			'\') echo -n '\\\\';continue; ;;
		esac
		
		#if -a (all) or outside printable ASCII range (less than 0x20 or greater than 0x7E) encode
		if ((${flag_a})) || [[ "${1:$i:1}" < $'\x20' ]] || [[ "${1:$i:1}" > $'\x7E' ]]; then
			#print UTF8 encoded \x escape style, leave xxd output unquoted to leverage each line as argument for printf
			printf "\\\x%s" $(echo -n "${1:$i:1}" | xxd -p -c1 -u)
		else
			#print character as-is
			echo -n "${1:$i:1}"
		fi
	done
	#add a newline to the end of the string
	echo ""
)

hexencode "${@}"

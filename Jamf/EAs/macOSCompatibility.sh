#!/bin/bash
: <<-LICENSE_BLOCK
macOSCompatibility - a Jamf EA to report macOS compatibility with alternate output modes for TEXT or CSV output
Copyright (c) 2020 Joel Bruner (https://github.com/brunerd)
Licensed under the MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
LICENSE_BLOCK


: <<-USAGE
macOSCompatibility [-c] [-v "<macOS Version List>"] [<ModelID>,...]
	Without ModelID(s) returns Jamf EA style result: <result>11</result>
Arguments: 
 -c for CSV output (includes header of versions)
	Otherwise if a Model is specified and -c is NOT used, the output with be TEXT
 -v "<macOS Version List>" a space delimted list of macOS versions like "10.14 10.15 11"
 	For versions to check in EA mode, edit the variable "versionsToCheck" with the versions
 ["<ModelID List>"] a space delimted list of ModelIDs to test, 
 	Use "ALL" test against the ALL_MACS variable within this script
	EA Mode is ONLY if Model ID is NOT specified

For maximum fun: 
./macOSCompatibility -c -v ALL ALL > ~/Desktop/macOSCompatibilityMatrix.csv

This will create a CSV with all models and all version (Quicklook does a fine job with CSV if you happen to not have Numbers installed)
USAGE

#hold shoft down for xtrace output
shiftKeyDown=$(osascript -l JavaScript -e "ObjC.import('Cocoa'); ($.NSEvent.modifierFlags & $.NSEventModifierFlagShift) > 1")
[ "${shiftKeyDown}" == "true" ] && xtraceFlag=1
[ "${xtraceFlag:=0}" == 1 ] && set -x

#command key for select debug output
commandKeyDown=$(osascript -l JavaScript -e "ObjC.import('Cocoa'); ($.NSEvent.modifierFlags & $.NSEventModifierFlagCommand) > 1")
[ "${commandKeyDown}" == "true" ] && debugFlag=1

#############
# VARIABLES #
#############

#versions you want to test models against, space delimted
#remove those you don't want to check on, add old or new ones you need to test
versionsToCheck="10.13 10.14 10.15 11"
#uncomment to always test against "all"
#versionsToCheck="10.4 10.5 10.6 10.7 10.8 10.9 10.10 10.11 10.12 10.13 10.14 10.15 11"

#if ALL is used for -v it will use this variable
versionsToCheck_ALL="10.4 10.5 10.6 10.7 10.8 10.9 10.10 10.11 10.12 10.13 10.14 10.15 11"

#For determining support:
#Macs: 
#	MacTracker - https://mactracker.ca
#VMWare: 
#	https://kb.vmware.com/s/article/2088571
#	https://partnerweb.vmware.com/comp_guide2/pdf/VMware_GOS_Compatibility_Guide.pdf
#Parallels: 
#	https://kb.parallels.com/en/114381

macOS10_4_MIN_MAX_SUPPORTED="
iMac4,1 iMac7,1
MacBook1,1 MacBook2,1
MacBookPro1,1 MacBookPro3,1
Macmini1,1 Macmini2,1
MacPro1,1 MacPro2,1
Xserve1,1 Xserve1,1
"

macOS10_5_MIN_MAX_SUPPORTED="
iMac4,1 iMac9,1
MacBook1,1 MacBook5,2
MacBookAir1,1 MacBookAir2,1
MacBookPro1,1 MacBookPro8,3
Macmini1,1 Macmini3,1
MacPro1,1 MacPro4,1
Xserve1,1 Xserve3,1
"

macOS10_6_MIN_MAX_SUPPORTED="
iMac4,1 iMac12,2
MacBook1,1 MacBook7,1
MacBookAir1,1 MacBookAir3,2
MacBookPro1,1 MacBookPro8,3
Macmini1,1 Macmini4,1
MacPro1,1 MacPro5,1
Xserve1,1 Xserve3,1
"

macOS10_7_MIN_MAX_SUPPORTED="
iMac5,1 iMac12,2
MacBook2,1 MacBook7,1
MacBookAir1,1 MacBookAir5,2
MacBookPro2,1 MacBookPro10,1
Macmini2,1 Macmini5,3
MacPro1,1 MacPro5,1
Xserve1,1 Xserve3,1
VMWare4,1 VMWare6,1
Parallels7,1 Parallels10,1"

macOS10_8_MIN_MAX_SUPPORTED="
iMac7,1 iMac14,3
MacBook5,1 MacBook7,1
MacBookAir2,1 MacBookAir6,2
MacBookPro3,1 MacBookPro10,2
Macmini2,1 Macmini6,2
MacPro3,1 MacPro5,1
Xserve3,1 Xserve3,1
VMWare5,1 VMWare7,1
Parallels8,1 Parallels10,1"

macOS10_9_MIN_MAX_SUPPORTED="
iMac7,1 iMac14,4
MacBook5,1 MacBook7,1
MacBookAir2,1 MacBookAir6,2
MacBookPro3,1 MacBookPro11,2
Macmini3,1 Macmini6,2
MacPro3,1 MacPro6,1
Xserve3,1 Xserve3,1
VMWare6,1 VMWare8,1
Parallels8,1 Parallels11,1"

macOS10_10_MIN_MAX_SUPPORTED="
iMac7,1 iMac15,1
MacBook5,1 MacBook8,1
MacBookAir2,1 MacBookAir7,2
MacBookPro3,1 MacBookPro11,5
Macmini3,1 Macmini7,1
MacPro3,1 MacPro6,1
Xserve3,1 Xserve3,1
VMWare7,1 VMWare8,1
Parallels9,1 Parallels13,1"

macOS10_11_MIN_MAX_SUPPORTED="
iMac7,1 iMac17,1
MacBook5,1 MacBook9,1
MacBookAir2,1 MacBookAir7,2
MacBookPro3,1 MacBookPro12,1
Macmini3,1 Macmini7,1
MacPro3,1 MacPro6,1
Xserve3,1 Xserve3,1
VMWare8,1 VMWare10,1
Parallels10,1 Parallels14,1"

macOS10_12_MIN_MAX_SUPPORTED="
iMac10,1 iMac18,3
MacBook6,1 MacBook10,1
MacBookAir3,1 MacBookAir7,2
MacBookPro6,1 MacBookPro14,3
Macmini4,1 Macmini7,1
MacPro5,1 MacPro6,1
VMWare8,1 VMWare11,1
Parallels11,1 Parallels15,1"

macOS10_13_MIN_MAX_SUPPORTED="
iMac10,1 iMac18,3
iMacPro1,1 iMacPro1,1
MacBook6,1 MacBook10,1
MacBookAir3,1 MacBookAir7,2
MacBookPro6,1 MacBookPro15,1
Macmini4,1 Macmini7,1
MacPro5,1 MacPro6,1
VMWare10,1 VMWare11,5 
Parallels13,1"
#BTW I am totally guessing on VMWare 11.5 ModelID of "VMWare11,5"

#Mac Pro 2010 and 2012 (MacPro6,1) can run IF metal compatible graphics card installed
macOS10_14_MIN_MAX_SUPPORTED="
iMac13,1 iMac19,1
iMacPro1,1 iMacPro1,1
MacBook8,1 MacBook10,1
MacBookAir5,1 MacBookAir8,2
MacBookPro9,1 MacBookPro15,4
Macmini6,1 Macmini8,1
MacPro5,1 MacPro6,1
VMWare11,1 VMWare11,5
Parallels14,1"

macOS10_15_MIN_MAX_SUPPORTED="
iMac13,1 iMac20,2
iMacPro1,1 iMacPro1,1
MacBook8,1 MacBook10,1
MacBookAir5,1 MacBookAir9,1
MacBookPro9,1 MacBookPro16,4
Macmini6,1 Macmini8,1
MacPro6,1 MacPro7,1
VMWare11,5
Parallels15,1"

macOS11_MIN_MAX_SUPPORTED="
iMac14,4
iMacPro1,1
MacBook8,1
MacBookAir6,1
MacBookPro11,1
Macmini7,1
MacPro6,1
VMWare12,1
Parallels16,1"

#macOS12_MIN_MAX_SUPPORTED=""

#NOTES:
#When a new OS ships this must be updated AT LEAST with the MINIMUM REQUIRED HARDWARE to run the OS
#keep the nomenclature: macOSxx[.xx]_MIN_MAX_SUPPORTED

#maximum hardware capable of running macOS
#find the model in MacTracker BEFORE the "Original OS" moves UP to the version ABOVE what you are testing for
#Basiclly leave MAX EMPTY until new hardware comes out that requires a NEWER macOS, use the PREVIOUS model for the MAX

#Used when "ALL" is specified for the Model ID
#Edit as necessary...
ALL_MACS="iMac4,1
iMac4,2
iMac5,1
iMac5,2
iMac6,1
iMac7,1
iMac8,1
iMac9,1
iMac10,1
iMac11,1
iMac11,2
iMac11,3
iMac12,1
iMac12,2
iMac13,1
iMac13,2
iMac14,1
iMac14,2
iMac14,3
iMac14,4
iMac15,1
iMac16,1
iMac16,2
iMac17,1
iMac18,1
iMac18,2
iMac18,3
iMac19,1
iMac20,1
iMac20,2
iMacPro1,1
MacBook1,1
MacBook2,1
MacBook3,1
MacBook4,1
MacBook5,1
MacBook6,1
MacBook7,1
MacBook8,1
MacBook9,1
MacBook10,1
MacBookAir1,1
MacBookAir2,1
MacBookAir3,2
MacBookAir4,1
MacBookAir4,2
MacBookAir5,1
MacBookAir5,2
MacBookAir6,1
MacBookAir6,2
MacBookAir7,1
MacBookAir7,2
MacBookAir8,1
MacBookAir8,2
MacBookAir9,1
MacBookAir10,1
MacBookPro1,1
MacBookPro1,2
MacBookPro2,1
MacBookPro2,2
MacBookPro3,1
MacBookPro4,1
MacBookPro5,1
MacBookPro5,2
MacBookPro5,3
MacBookPro5,4
MacBookPro5,5
MacBookPro6,1
MacBookPro6,2
MacBookPro7,1
MacBookPro8,1
MacBookPro8,2
MacBookPro8,3
MacBookPro9,1
MacBookPro9,2
MacBookPro10,1
MacBookPro10,2
MacBookPro11,1
MacBookPro11,2
MacBookPro11,3
MacBookPro11,4
MacBookPro11,5
MacBookPro12,1
MacBookPro13,1
MacBookPro13,2
MacBookPro13,3
MacBookPro14,1
MacBookPro14,2
MacBookPro14,3
MacBookPro15,1
MacBookPro15,2
MacBookPro15,3
MacBookPro15,4
MacBookPro16,1
MacBookPro16,2
MacBookPro16,3
MacBookPro16,4
MacBookPro17,1
Macmini1,1
Macmini2,1
Macmini3,1
Macmini4,1
Macmini5,1
Macmini5,2
Macmini5,3
Macmini6,1
Macmini6,2
Macmini7,1
Macmini8,1
Macmini9,1
MacPro1,1
MacPro2,1
MacPro3,1
MacPro4,1
MacPro5,1
MacPro6,1
MacPro7,1
Xserve1,1
Xserve2,1
Xserve3,1
#Virtual Machines
VMWare6,1
VMWare7,1
VMWare8,1
VMWare10,1
VMWare11,1
VMWare11,5
VMWare12,1
Parallels8,1
Parallels9,1
Parallels10,1
Parallels11,1
Parallels12,1
Parallels13,1
Parallels14,1
Parallels15,1
Parallels16,1
#these do not exist yet...
iMacPro2,1
"

#############
# FUNCTIONS #
#############

#output stats for all the macs in the TESTMAC variable
function getCompatibleOSes
{
	local modelList="${1}"
	local modelListArray=( ${modelList} )

	#echo "modelListArray @: ${modelListArray[@]}"
	#echo "modelListArray #: ${#modelListArray[@]}"
	
	#IFS for comment lines with spaces
	IFS=$'\n' 

	[ "${runMode}" == "CSV" ] && echo "ModelID,$(tr " " "," <<< "${versionsToCheck}" )"

	#go through all the models in ALL_MACS
	for myModelID in ${modelList}; do
		
		[ "${debugFlag:=0}" == 1 ] && echo "myModelID: ${myModelID}" >/dev/stderr
		
		#set IFS back
		IFS=$' \t\n'

		#if not an EA echo out the #comment lines
		[ "${runMode}" != "EA" ] && [ "${myModelID:0:1}" == "#" ] && { echo $myModelID; continue; }
		
		#echo out the model in double quotes
		if [ "${runMode}" == "CSV" ]; then
			echo -n "\"${myModelID}\""
		#if not an EA echo out the model textually 
		elif [ "${runMode}" == "TEXT" ]; then
			echo -n "${myModelID}:"
		fi
		
		#loop through global versionsToCheck and append each compatible version to myVersions
		for version in ${versionsToCheck}; do
			#assign or append return value to variable myVersions
			checkOutput=$(checkCompatbility "${version}")
			[ "${debugFlag:=0}" == 1 ] && echo "version: ${version}, checkOutput: \"${checkOutput}\"" >/dev/stderr

			#append the output to the myVersions string
			myVersions+="${FS}${checkOutput}"
		done

		#trim leading and trailing spaces
		myVersions=$(sed -e $'s/^[ \t]*//' -e $'s/[ \t]*$//' <<< "${myVersions}")

		#output for EA
		if [ "${runMode}" == "EA" ]; then
			echo "<result>${myVersions}</result>"
		#text with one leading space after :
		elif [ "${runMode}" == "CSV" ]; then
			echo "${myVersions}"
		else
		#output for CSV
			echo " ${myVersions}"
		fi

		#unset for the next loop
		unset myVersions
	done
}

function checkCompatbility
{
	#name of the OS variable to check (example 10_15 or 11)
	local versionToTest="${1}"

	#underscore version: 10.x to 10_x
	local _versionToTest=$(tr "." "_" <<< "${versionToTest}")

	#extract MODEL name
	local myModel_Name=$(awk '{gsub(/[^A-Za-z]/,""); print $0}' <<< "${myModelID}" | cut -d, -f1)
	#extract MAJOR number, remove anything not a number or comma, get first field before comma
	local myModel_Major=$(awk '{gsub(/[^0-9,]/,""); print $0}' <<< "${myModelID}" | cut -d, -f1)
	#extract MINOR number,remove anything not a number or comma, get first field after comma
	local myModel_Minor=$(awk '{gsub(/[^0-9,]/,""); print $0}' <<< "${myModelID}" | cut -d, -f2)

	#get the line with the models, then store MIN/MAX values in an array
	local versionToTest_myModelArray=( $(grep "^${myModel_Name}[[:digit:]]" <<< "$(eval echo \"\$macOS${_versionToTest}_MIN_MAX_SUPPORTED\")") )

	#get the MINIMUM models from our family for the version we are checking
	local versionMyModelID_MIN=${versionToTest_myModelArray[0]}

	#get the MAXIMUM models from our family for the version we are checking
	local versionMyModelID_MAX=${versionToTest_myModelArray[1]}

	#take care of no max (yet) by setting threshold high
	if [ -z "${versionModelIDs_MAX}" ]; then
		versionModelIDs_MAX="${myModel_Name}99,99"
	fi

	#extract MAJOR number of the MIN hardware, remove anything not a number or comma, get first field before comma
	local versionMyModelIDMajor_MIN=$(awk '{gsub(/[^0-9,]/,""); print $0}' <<< "${versionMyModelID_MIN}" | cut -d, -f1)
	#extract MINOR number of the MIN hardware, remove anything not a number or comma, get second field before comma
	local versionMyModelIDMinor_MIN=$(awk '{gsub(/[^0-9,]/,""); print $0}' <<< "${versionMyModelID_MIN}" | cut -d, -f2)

	#extract MAJOR number of the MAX hardware, remove anything not a number or comma, get first field before comma
	local versionMyModelIDMajor_MAX=$(awk '{gsub(/[^0-9,]/,""); print $0}' <<< "${versionMyModelID_MAX}" | cut -d, -f1)
	#extract MINOR number of the MAX hardware, remove anything not a number or comma, get second field before comma
	local versionMyModelIDMinor_MAX=$(awk '{gsub(/[^0-9,]/,""); print $0}' <<< "${versionMyModelID_MAX}" | cut -d, -f2)

	#if the MAJOR HW value falls in BETWEEN the range of this OS
	if [ "${myModel_Major}" -gt "${versionMyModelIDMajor_MIN:-99}" -a "${myModel_Major}" -lt "${versionMyModelIDMajor_MAX:-99}" ]; then
		#change 10_x to 10.x
		supportedOS_output="${versionToTest}"
	#if the MAJOR value EQUALS the MIN, ensure the MINOR is GREATER or EQUAL (if unset make it a high number)
	elif [ "${myModel_Major}" -eq "${versionMyModelIDMajor_MIN:-99}" -a "${myModel_Minor}" -ge "${versionMyModelIDMinor_MIN:-99}" ]; then
		#change 10_x to 10.x
		supportedOS_output="${versionToTest}"
	#if the MAJOR value that EQUALS the MAX and ensure the MINOR is LESS or EQUAL (if unset make it 0)
	elif [ "${myModel_Major}" -eq "${versionMyModelIDMajor_MAX:-99}" -a "${myModel_Minor}" -le "${versionMyModelIDMinor_MAX:-0}" ]; then
		#change 10_x to 10.x
		supportedOS_output="${versionToTest}"
	fi

	#clean trailing whitespace
	supportedOS_output=$(sed $'s/[ \t]*$//' <<< "${supportedOS_output}")

	if [ "${runMode}" == "EA" ]; then
		#special metal check for 2010 and 2012 MacPros
		#make these vars now so we can substitute below if empty
		local thisMinor="${supportedOS_output/*.}"
		local thisMajor="${supportedOS_output/.*}"
		if [ "${myModelID}" = "MacPro5,1" ] && [ "${thisMajor:-0}" -eq 10 -a "${thisMinor:-0}" -ge "14" ]; then
			#check for metal, this is only for the HOST running this script, thus beware, DO NOT use for API writing to other computer records
			sysPrefs_Metal=$(system_profiler SPDisplaysDataType | grep "Metal" | awk -F': ' '{print $2}')
			#if "Supported" is not found in the output string then empty the variable
			[ -z "$(grep "Supported" <<< "${sysPrefs_Metal}")" ] && supportedOS_output=''
		fi
	fi
	
	#echo this out no newline (may be empty)
	echo -n "${supportedOS_output}"
}

########
# MAIN #
########

#defaults
#field separator
FS=" "
runMode="TEXT"

#get any option
while getopts ":cv:" option; do
	case "${option}" in
		#CSVoutput for all
		'c')
			runMode="CSV"
			#set a field separator
			FS=","
			;;	
		'v')
			#set the version to specified space separated list of OSes
			#or if ALL is used then set to ${versionsToCheck_ALL}
			[ "${OPTARG}" == "ALL" ] && versionsToCheck="${versionsToCheck_ALL}" || versionsToCheck="${OPTARG}"
			;;	
	esac
done

# Shift so positional parameters are in the correct place after options processing
shift $(( OPTIND - 1 ))

#if we have an argument
if [ "${#}" -gt 0 ]; then
	#"ALL" will test all models in the ALL_MACS variable
	#otherwise create a newline delimited list
	[ "${1}" == "ALL" ] && modelList="${ALL_MACS}" || modelList=$(tr ' ' $'\n' <<< "${@}")
#if no arguments
else
	#if no arguments then we will output XML in EA mode
	[ "${runMode}" != "CSV" ] && runMode="EA"	
	#if CSV use commas, otherwise use spaces
	[ "${runMode}" == "CSV" ] && FS="," || FS=" "

	#get our model
	modelList=$(/usr/sbin/sysctl -n hw.model)

	#if that failed for some odd reason get it another (slower) way
	if [ -z "${myModelID}" ]; then
		modelList=$(system_profiler SPHardwareDataType -nospawn -detailLevel mini | awk '/Model Identifier/{print $3}')
		#alt method for getting modelID, a bit slower but more sure
		#modelList=$(/usr/libexec/PlistBuddy -c "print :0:_items:0:machine_model" /dev/stdin 2>/dev/stderr <<< "$(/usr/sbin/system_profiler -nospawn -xml SPHardwareDataType -detailLevel mini)")
	fi
fi

#pass all models to function for output
getCompatibleOSes "${modelList}"

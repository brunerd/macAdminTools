#!/bin/bash
#Joel Bruner (repo: https://github.com/brunerd, blog: https://brunerd.com/blog)
##iCloudDrive - gets the iCloud Drive status for a console user

#############
# FUNCTIONS #
#############

function iCloudDrive()(
    consoleUser=$(stat -f %Su /dev/console)
    
    #if root grab the last console user
    if [ "${consoleUser}" = "root" ]; then
        consoleUser=$(/usr/bin/last -1 -t console | awk '{print $1}')
    fi
    
    #get the home folder
    userHome=$(dscl /Local/Default -read /Users/"${consoleUser}" NFSHomeDirectory | awk '{print $NF}')
    
    #this folder only exists when iCloud Drive is On
    if [ -d "${userHome}/Library/Mobile Documents" ]; then
        return 0
    else
        return 1
    fi
)

########
# MAIN #
########

#example function usage, if leverages the return values
if iCloudDrive; then
	echo "iCloud Drive is ON"
	exit 0
else
	echo "iCloud Drive is OFF"
	exit 1
fi

#!/bin/bash
#
###############################################################################################################################################
#
# ABOUT THIS PROGRAM
#
#   This Script is designed for use in JAMF
#
#   - This script will ...
#			check the SCC Database to see if the specified Application
#				is enabled for Screen Recording
#
#	- For this to function Correctly, Config Profiles will be needed to
#		grant JAMF further permissions to access the TCC Database
#		- At present this seems to be sending Apple Events to System Events
#			and Full Disk Access, but this may possibly be able to be reduced a little.
#
###############################################################################################################################################
#
# HISTORY
#
#	Version: 1.1 - 09/01/2020
#
#	- 07/01/2020 - V1.0 - Created by Headbolt
#
#   - 09/01/2020 - V1.1 - Updated by Headbolt
#							More comprehensive error checking and notation
#
###############################################################################################################################################
#
# DEFINE VARIABLES & READ IN PARAMETERS
#
###############################################################################################################################################
#
User=$3 # Grab the Username of the current logged in user from built in JAMF variable #3
AppIDstring=$4 # Grab the identifier to use when searching the TCC Database from JAMF variable #4 eg ScreenConnect
# Note : this can usually be found by manually allowing on a test machine and then running the below command
# sqlite3 /Library/Application\ Support/com.apple.TCC/TCC.db 'select * from access'
# Note : This variable is used for screen output later but searches the database in a non case specific manner
#
AppName=$5 # Grab the app name to use in the Privcy Window from JAMF variable #5 eg connectwisecontrol-abcd1234efgh5678
#
# Set the name of the script for later logging
ScriptName="append prefix here as needed - Application ScreenRecording Permissions"
#
###############################################################################################################################################
#
# SCRIPT CONTENTS - DO NOT MODIFY BELOW THIS LINE
#
###############################################################################################################################################
#
# Defining Functions
#
###############################################################################################################################################
#
# Check System Preferences Process ID Function
#
CheckSysPrefProccesses(){
#
# Setting Command to be Run
#
ProcessCheckCommand=$(echo '
if application "System Preferences" is running then
	tell application "System Preferences" to quit
end if
 '
)
#
/bin/echo 'Checking System Preferences Application'
/bin/echo 'and killing it if it is Running'
/bin/echo # Outputting a Blank Line for Reporting Purposes
#
if [[ "$User" != "" ]] # Checking if a user is logged in
	then
		/bin/echo 'Running Command'
		/bin/echo # Outputting a Blank Line for Reporting Purposes
		#
		/bin/echo sudo -u $User osascript -e "'"$ProcessCheckCommand"'" # Displaying Command to be run
		#
		sudo -u $User osascript -e "$ProcessCheckCommand" #Executing Command
	else
		/bin/echo 'No User Logged in, cannot run command'
fi
#
}
#
###############################################################################################################################################
#
# ScreenConnect Status Check Function
#
AppStatusCheck(){
#
/bin/echo "Checking Current Permissions"
#
App=$(sqlite3 /Library/Application\ Support/com.apple.TCC/TCC.db 'select * from access' | grep -i $AppIDstring) # Find the line for the App
AccErr=$(sqlite3 /Library/Application\ Support/com.apple.TCC/TCC.db 'select * from access' 2>&1 | grep unable) # Check for permissions error
read -ra AppStatusArray <<< "$App" # Read In the Array
#
IFS='|' # Internal Field Seperator Delimiter is set to Pipe (|)
AppStatus=$(echo $AppStatusArray | awk '{ print $4 }')
unset IFS
#
if [[ "$AccErr" == "" ]] # Check if there was a permissions error accessing the TCC.db file
	then
		if [[ $AppStatus == 1 ]] # Check if the app has Screen Recording permission enabled
			then
				RESULT="SET"
			else
				if [[ $AppStatus == "" ]]
					then
						RESULT="NOT PRESENT"
					else
						RESULT="NOT SET"
				fi
		fi
	else 
		RESULT="PERMISSIONS ERROR"
fi
#
/bin/echo $AppIDstring "ScreenRecording Permissions" $RESULT
#
}
#
###############################################################################################################################################
#
# Set ScreenConnect Permissions Function
#
SetPerms(){
#
# Setting Command to be Run
#
PermissionsCommand=$(echo '
tell application "System Events"
	tell process "System Preferences"
		click checkbox 1 of UI element "'"$AppName"'" of row 1 of table 1 of scroll area 1 of group 1 of tab group 1 of window 1
		click button "Quit Now" of sheet 1 of window "Security & Privacy"
	end tell
end tell
#
if application "System Preferences" is running then
	tell application "System Preferences"
		quit
	end tell
end if
 '
)
#
/bin/echo "Setting Permissions"
/bin/echo # Outputting a Blank Line for Reporting Purposes

if [[ "$User" != "" ]] # Checking if a user is logged in
	then
		/bin/echo 'Running Command'
		/bin/echo # Outputting a Blank Line for Reporting Purposes
		#
		/bin/echo sudo -u $User osascript -e "'"$PermissionsCommand"'" # Displaying Command to be run
		#
		sudo -u $User osascript -e "$PermissionsCommand" #Executing Command
	else
		/bin/echo 'No User Logged in, cannot run command'
fi
#
}
#
###############################################################################################################################################
#
# Section End Function
#
SectionEnd(){
#
/bin/echo # Outputting a Blank Line for Reporting Purposes
#
/bin/echo  ----------------------------------------------- # Outputting a Dotted Line for Reporting Purposes
#
/bin/echo # Outputting a Blank Line for Reporting Purposes
#
}
#
###############################################################################################################################################
#
# Script End Function
#
ScriptEnd(){
#
/bin/echo Ending Script '"'$ScriptName'"'
#
/bin/echo # Outputting a Blank Line for Reporting Purposes
#
/bin/echo  ----------------------------------------------- # Outputting a Dotted Line for Reporting Purposes
#
/bin/echo # Outputting a Blank Line for Reporting Purposes
#
}
#
###############################################################################################################################################
#
# End Of Function Definition
#
###############################################################################################################################################
#
# Beginning Processing
#
###############################################################################################################################################
#
# Outputting a Blank Line for Reporting Purposes
/bin/echo
#
SectionEnd
#
CheckSysPrefProccesses
SectionEnd
sleep 5
#
AppStatusCheck
#
if [[ $AppStatus != 1 ]]
	then
		SectionEnd
		#
		open 'x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture'
		sleep 1
		SetPerms
		SectionEnd
		#
		AppStatusCheck
fi
#
SectionEnd
ScriptEnd

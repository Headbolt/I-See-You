#!/bin/bash
#
###############################################################################################################################################
#
# ABOUT THIS PROGRAM
#
#	I-See-You.sh
#	https://github.com/Headbolt/I-See-You
#
#   This Script is designed for use in JAMF as a Script in a policy called by a custom trigger,
#		slaved to a Login Policy that calls this Policy and exits without waiting, this is to
#		counter the GUI not starting until after the script has completed.
#		
#		This is deigned to run in conjunction with an Extension Attribute
#		By the same Author named "JAMF-Ext-ScreenRec-Perm" also available on GitHub
#		https://github.com/Headbolt/JAMF-Ext-ScreenRec-Perm
#
#   - This script will ...
#			check the SCC Database to see if the specified Application
#				is enabled for Screen Recording
#
#	- For this to function Correctly, Config Profiles will be needed to
#		grant JAMF or any other program needed further permissions to access the TCC Database
#	- At present this seems to be Accessibility	and Full Disk Access, but this may possibly be able to be reduced a little.
#
#	Programs that may require this would be.
#		JAMF - Obviously
#		Terminal - If this would be required to be run manually (or the Policy triggered) from that program
#		SSHD - If this would be required to be run manually (or the Policy triggered) from a remote SSH Window
#
#		Any other remote Management program (This was originally written to facilitate ScreenConnect)
#		that can remote execute code or Programs (Such as ScreenConnect) would also need these permissions
#
###############################################################################################################################################
#
# HISTORY
#
#	Version: 1.4 - 26/11/2020
#
#	- 07/01/2020 - V1.0 - Created by Headbolt
#
#	- 09/01/2020 - V1.1 - Updated by Headbolt
#							More comprehensive error checking and notation
#   - 13/01/2020 - V1.2 - Updated by Headbolt
#							Now allows for multiple entries by the target app, by filtering first
#								for kTCCServiceScreenCapture and then the App Name
#   - 14/01/2020 - V1.3 - Updated by Headbolt
#							Now allows for multiple in the table, process got derailed by having more
#								than 1 app in the window, large oversight missed by test machines being
#								fresh builds for purpose, issue discovered once tested on "Live" machines,
#								we now read in the number of rows in the table and step through them to find a match.
#   - 26/11/2020 - V1.4 - Updated by Headbolt
# 							Added a check incase BASH not avaialable (MacOS 10.15.7 and above) and shell drops back to ZSH
#								In Which Case an extra command is needed to utilise the Internal Field Separator
#								Also added an OS Version Check to determine the Syntax for the Applescript
# 									In Big Sur and later, after applying Screen Recording Permissions, 
# 									the Prompt to reopen the program just granted Screen Recording Permissions has changed.
# 									In Catalina, the prompt was "Later" or "Quit Now", In Big Sur, the prompt is "Later" or "Quit & Reopen"
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
ScriptName="ZZ 22 - Security & Privacy - Application ScreenRecording Permissions"
#
osMajor=$( /usr/bin/sw_vers -productVersion | /usr/bin/awk -F. '{print $1}' ) # Grab the Major OS Version
osMinor=$( /usr/bin/sw_vers -productVersion | /usr/bin/awk -F. '{print $2}' ) # Grab the Minor OS Version
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
App=$(sqlite3 /Library/Application\ Support/com.apple.TCC/TCC.db 'select * from access' | grep -i kTCCServiceScreenCapture | grep -i $AppIDstring) # Find the line for the App
AccErr=$(sqlite3 /Library/Application\ Support/com.apple.TCC/TCC.db 'select * from access' 2>&1 | grep unable) # Check for permissions error
#
IFS='|' # Internal Field Seperator Delimiter is set to Pipe (|)
#
if [ $ZSH_VERSION ] # If Using ZSH instead of Bash then wordsplit needs enabling for the IFS to work
	then
		setopt sh_word_split
fi
#
AppStatus=$(echo $App | awk '{ print $4 }')
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
CAT="NO" # Setting the CATplus Variable to No as a starting point
SURplus="NO" # Setting the SURplus Variable to No as a starting point
#
# Check the OS Version Number to determine the Syntax for the Applescript
# In Big Sur and later, after applying Screen Recording Permissions, 
# the Prompt to reopen the program just granted Screen Recording Permissions has changed.
# In Catalina, the prompt was "Later" or "Quit Now", In Big Sur, the prompt is "Later" or "Quit & Reopen"
#
if [[ "$osMajor" -lt "11" ]]
	then
		if [[ "$osMajor" -lt "10" ]]
			then
				CAT="NO"
			else 
				if [[ "$osMinor" -le "14" ]]
					then
						CAT="NO"
					else
						if [[ "$osMinor" -eq "15" ]]
							then
								CAT="YES"
							else
								if [[ "$osMinor" -ge "16" ]]
									then
										SURplus="YES"
								fi
						fi
				fi
		fi
	else
		SURplus="YES"
fi
#
if [[ "$CAT" == "YES" ]] # If OS is determined to be Catalina, run relevant piece of AppleScript
	then
		PermissionsCommand=$(echo '
		tell application "System Events"
			tell process "System Preferences"
				set NumOfRows to number of rows of table 1 of scroll area 1 of group 1 of tab group 1 of window 1
				set i to 1
				repeat while i < (NumOfRows + 1)
					set AppVal to value of item 1 of static text 1 of UI element 1 of row i of table 1 of scroll area 1 of group 1 of tab group 1 of window 1
					if (AppVal = "'"$AppName"'") then
						click checkbox 1 of UI element 1 of row i of table 1 of scroll area 1 of group 1 of tab group 1 of window 1
						click button "Quit Now" of sheet 1 of window "Security & Privacy"
					end if
					set i to i + 1
				end repeat
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
fi
#
if [[ "$SURplus" == "YES" ]] # If OS is determined to be Big Sur or Higher, run relevant piece of AppleScript
	then
		PermissionsCommand=$(echo '
		tell application "System Events"
			tell process "System Preferences"
				set NumOfRows to number of rows of table 1 of scroll area 1 of group 1 of tab group 1 of window 1
				set i to 1
				repeat while i < (NumOfRows + 1)
					set AppVal to value of item 1 of static text 1 of UI element 1 of row i of table 1 of scroll area 1 of group 1 of tab group 1 of window 1
					if (AppVal = "'"$AppName"'") then
						click checkbox 1 of UI element 1 of row i of table 1 of scroll area 1 of group 1 of tab group 1 of window 1
						click button "Quit & Reopen" of sheet 1 of window "Security & Privacy"
					end if
					set i to i + 1
				end repeat
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
fi
#
# Run the relevant Applescript to set permissions
#
/bin/echo "Setting Permissions"
/bin/echo # Outputting a Blank Line for Reporting Purposes
#
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
if [[ $AppStatus != 1 ]] # If Application is not Enabled for ScreenRecording, begin processing
	then
		SectionEnd
		#
		open 'x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture' # Open correct System Preferences Page
		sleep 1 # Pause to allow it time to open
		SetPerms
		SectionEnd
		#
		AppStatusCheck
fi
#
SectionEnd
ScriptEnd

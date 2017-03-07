#!/bin/bash

# Written by Vince Loschiavo
# March 1st, 2017
# Caution - beta: work in progress....

# This is a menu handler for vloradio (Raspberry Pi based Pandora Player with LCD, Rotary Encoder, push buttons, and infrared remote)

# When the Menu is called initially, Draw the first two lines of the menu

# Keep track of menu position via environment variables to survive subsequent calls and redraw the screen with the current menu item
# on the first line of the LCD and the next item on the second line.


##################################################################
# Import config
if [ -z $SCRIPTSBASEDIR ]
then
        export SCRIPTSBASEDIR="/home/vloschiavo/src/vloradio"
fi

# Import configs
. ${SCRIPTSBASEDIR}/config.sh
MENUCTL=${EPHEMERAL}/menuctl
. ${MENUCTL}
##################################################################


##################################################################
# Define Variables

# Button timeout interval
INTERVAL=6

# Menus
Menus=("MainMenu" "TemperatureMenu" "SystemMenu")

# Menu items:
MainMenu=("Change Station" "Temperature Data" "System Control" "Test Message")

# Temperature Sub Menu of Main Menu:
TemperatureMenu=("Room Temp/Humid" "CPU Temp")

# System Sub Menu of Main Menu:
SystemMenu=("Shutdown" "")

# Button Pressed on remote (passed in from irexec)
BUTTON=$1
##################################################################


##################################################################
# Functions:
##################################################################

# Display current menu item and next menu item 
DISPLAYMENU(){ 
	# Displays menu and keeps track of where in the menu we are

	# Get the name of the current Menu		
	menuName=${Menus[$selectedMenu]}

	# Copy the array into a temporary array - elements to be dereferenced later
	currentMenu=("${MainMenu[@]}")

	# Display the selected item and the next item

	# Make sure we're inbounds (compare against the size of the array and 0)
	if [ "$selectedItem" -ge "${#currentMenu[@]}" ] || [ "$selectedItem" -lt 0 ]; then
		export selectedItem=0
		nextItem=$selectedItem+1;
		echo "ge set si=0"
	elif [ "$selectedItem" -eq "${#currentMenu[@]}" ]; then
		nextItem=0
		echo "eq, set ni=0"
	else
		nextItem=$selectedItem+1;
		echo "ni=si+1"
		
	fi
	echo $selectedItem

	./DisplayLCDMessage.py ">${currentMenu[$selectedItem]}" "-${currentMenu[$nextItem]}";

	# Update the button push time
	SETBUTTONPUSHTIME
}

# Stores list of stations in array 
READSTATIONS(){
	
	# This function stores the stations and it's associated number to be called later
	# i.e. ${StationNumber[2]} is pianobar's number for Station Name: ${StationName[2]}
	# Sets IFS to the default and reads the Station Numbers
	IFS=$' \t\n'
	StationNumber=($(cut -d: -f1 ${EPHEMERAL}/stationList))

	# Put station names into array (including spaces in station names)
	IFS=$'\n'
	StationName=($(cut -d':' -f2 ${EPHEMERAL}/stationList))

	# Reset the Internal Field Separator
	IFS=$' \t\n'
}

SETBUTTONPUSHTIME(){
	# Store the button pushed time in seconds since Epoch
        export BUTTONPUSHTIME=`date +%s`
}


#Check to see if the timeout has expired.
CHECKTIMEOUT(){
	# Get the current time in seconds since Epoch
	CURRENTTIME=`date +%s`

	# If current time minus previous time less then the interval then do the thing
	if (("$CURRENTSECONDS" - "$PREVIOUSSECONDS" <= "$INTERVAL"))
	then
		INMENU=1

	# Timeout expired - it's been too long since user pressed a remote button
	else
		INMENU=0
		# Redraw Now Playing:
		
	fi


}




##################################################################
# Begin Main
##################################################################
#	
#	
# goes into case statement
# Press Menu
# 	Call Display Menu function
#
# Press KEY_CHANNELDOWN 
#	increment menu item counter
#	DISPLAYMENU
#	
# Press KEY_CHANNELUP
#	decrement menu item counter
#	DISPLAYMENU
#
# Press Enter Key within timelimit (5 sec?)
#	activate current menu item 
#	DISPLAYMENU if it's a new menu/sub-menu
# 
#
##################################################################




case "$BUTTON" in

	MENU)
		DISPLAYMENU

		;;

	CH+)
		echo $selectedItem
		((selectedItem+=1))
		echo $selectedItem
		export selectedItem
		DISPLAYMENU

		;;

esac
# ((selectedItem++)) / ((selectedItem--))
	#case "$BUTTON" in
# If BUTTONPUSHTIME is null (never set)
#if [ -z "$BUTTONPUSHTIME" ]; then
	# Menu was never called so user pressed wrong button on remote
#	exit;
#fi
#	MENU)	
#	CH+)
#		# Increment 
#		if [ "$selectedMenu" -lt ${#MainMenu[@]} -a -ge 0 ]; then
#			# show the menu
#		else
#			$selectedMenu=0
#		fi
#		;;
#
#	CH-)
#		# Stuff
#		
#		;;
#
#	ENTER)
#		# Stuff
#
#		;;
#
#	RETURN)
#		# Stuff
#
#		;;

#	esac
# Check if we're in the menu and within the timeout
#CHECKTIMEOUT
##################################################################

##########################
##!/bin/bash
#
#configFile=./crap.sh
#
#. $configFile
#
#writeConfig() {
#        key=$1
#        [ -z "$key" ] && return
#        value=$2
#        sed -i "/$key=/c\\$key=$value" $configFile
# Remove in favor of creating the file on boot #        [ -z "$( grep $key= $configFile )" ] && echo "$key=$value" > $configFile
#}
#
#
#[ -n "$1" ] && {
#        writeConfig $@
#}


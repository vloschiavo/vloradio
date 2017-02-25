#!/bin/bash
##################################################################
# Written by V. Loschiavo 
# Feb 12 2017
# Pandora player (vloradio) button handler
# Don't forget your pull up resistors (or use the internal pullups per the below:
# Initial idea taken from: https://github.com/AyMac/Pandoras-Box
#
# Adapted to use clock delay versus sleep from: https://www.arduino.cc/en/Tutorial/BlinkWithoutDelay
# 
# I put the following commands in the pianobar startup script for each button pin
# gpio -g mode 6 in	# Sets pin mode to input
# gpio -g mode 6 up	# Sets internal pull-up resistor
# gpio-watch 6:switch	# Sets up an interrupt on pin 6 with the "switch" type (switch uses a 100ms (100000us) software debounce)
#
# Broadcom GPIO 	|
# Pin number number	|	Function
# ----------------------------------------------------------
#	6		|	Tap=Redraw Now Playing 	/ Hold=Shutdown
#	12		|	Tap=Display Temp	/ Hold=Skip Track
#	16		|	Tap=Love song		/ Hold=Ban song
# 	18		|	Tap=Mute/Unmute		/ Hold=Return to sane volume level
#	19		|	Tap=Play/Pause		/ Hold=Tired of Song
#	20		|	Tap=Menu/Select		/ Hold=Go back
# -----------------------------------------------------------
#
# $1 = the GPIO pin triggered
# $2 = the value of the pin (0 || 1)
#
##################################################################

TRIGGEREDPIN=$1

# User defined Variables:

# Interval, in seconds, which the button needs to be held

if [ $TRIGGEREDPIN = 6 ]
then
	# Make the interval longer for the shutdown button
	INTERVAL=3
else 
	INTERVAL=1
fi

# Ensure there are some values if they weren't set elsewhere.
if [ -z $SCRIPTSBASEDIR ]
then
	export SCRIPTSBASEDIR="/home/vloschiavo/src/vloradio"
fi

if [ -z $EPHEMERAL ]
then
	export EPHEMERAL="/var/tmp"
fi

if [ ! -f /var/tmp/pandoraout ]
then
	touch /var/tmp/pandoraout
fi

if [ -z $CTLFILE ]
then
	export CTLFILE="/var/tmp/ctl"
fi


#Locations of other scripts
DISPLAYMESSAGE="${SCRIPTSBASEDIR}/DisplayLCDMessage.py"
PARSEANDWRITE2LCD="${SCRIPTSBASEDIR}/ParseAndWrite.py"


##################################################################
# Begin Main
##################################################################

##################################################################
# Determine if the button was a short or long press
##################################################################
shortlong=""
# Get the current time in seconds since Epoch
PREVIOUSSECONDS=`date +%s`

# While the pin is pulled low (you are pressing the button), do some stuff
while [ $(gpio -g read $TRIGGEREDPIN) = 0 ]
do
	# Get the current time in seconds at the beginning of the loop
	CURRENTSECONDS=`date +%s`

	# If current time minus previous time through the loop is less then the interval then sleep
	if (("$CURRENTSECONDS" - "$PREVIOUSSECONDS" <= "$INTERVAL"))
	then
		sleep .1	# Added the sleep for 1/10th of a second to reduce clock cycles spent monitoring this pin
	
	# If the user has been holding the button for the interval (or longer) then it was a long press
	else
		shortlong="long"
		break
	fi
	
done
	
# Check if the user let go of the button before reaching the interval
	
# if the shortlong variable is empty, then set it to "short"
if [ -z "$shortlong" ]; then
	shortlong="short"
fi
##################################################################

case "$TRIGGEREDPIN" in

6)	# Redraw / Shutdown Pin Pressed
	if [ $shortlong == "short" ]; then
		# Redraw the "Now Playing Screen"
        	$PARSEANDWRITE2LCD
	fi

	if [ $shortlong == "long" ]; then
                # Display shutdown message and shutdown
                $DISPLAYMESSAGE "Shutting Down" "Now Goodbye"
                sudo shutdown -h now            # Power off the Pi
	fi

	;;
	

12)	# Display Temperature / Next Song Button
	if [ $shortlong == "short" ]; then
		temphumid=`${HOME}/src/Adafruit_Python_DHT/examples/simpletest.py` && $DISPLAYMESSAGE $temphumid
		sleep 5
		$PARSEANDWRITE2LCD
	fi

	if [ $shortlong == "long" ]; then
        	$DISPLAYMESSAGE "Skipping song" ""
		echo -n 'n' >> $CTLFILE
	fi

	;;
	

16)	# Love / Ban Song
	if [ $shortlong == "short" ]; then
		# Get the song title and love the song
		songtitle=`sed -n '1p' $EPHEMERAL/pandoraout`;
        	$DISPLAYMESSAGE "Loving song:" "$songtitle"
		echo -n '+' >> $CTLFILE
	fi

	if [ $shortlong == "long" ]; then
		# Get the song title and ban the song
		songtitle=`sed -n '1p' $EPHEMERAL/pandoraout`;
        	$DISPLAYMESSAGE "Banning song:" "$songtitle"
		echo -n '-' >> $CTLFILE
	fi

	;;
	

18)	# Mute/Unmute toggle / Return to default volume level
	if [ $shortlong == "short" ]; then

		# Toggle the mute button and store the output in variable $mute
		mute=`amixer set PCM toggle`

		if [[ $mute =~ \[on\] ]]
		then 
			($DISPLAYMESSAGE "Mute is" "Off"; sleep 1; $PARSEANDWRITE2LCD) &
		fi

		if [[ $mute =~ \[off\] ]]
		then 
			($DISPLAYMESSAGE "Mute is" "On"; sleep 1; $PARSEANDWRITE2LCD) &
		fi
        	
	fi

	if [ $shortlong == "long" ]; then
		$DISPLAYMESSAGE "Resetting" "volume"
		echo -n '^' >> $CTLFILE
		sleep 1
		$PARSEANDWRITE2LCD
	fi

	;;
	
19)	# Play/Pause / Tired of Song
	if [ $shortlong == "short" ]; then
		# Indicate the button was pressed then redraw the Now Playing screen
		($DISPLAYMESSAGE "Play/Pause" ""; sleep 2; $PARSEANDWRITE2LCD) &
		echo -n 'p' >> $CTLFILE
	fi

	if [ $shortlong == "long" ]; then
       		$DISPLAYMESSAGE "Ban song" "for 1 month"
		echo -n 't' >> $CTLFILE
	fi

	;;

20)	# Not implemented yet: Menu/Select  /   Go back
	if [ $shortlong == "short" ]; then
        	$DISPLAYMESSAGE "Menu" "Select"
	fi

	if [ $shortlong == "long" ]; then
       		$DISPLAYMESSAGE "Go" "Back"
	fi

	;;
	
esac

#!/bin/bash
##################################################################
# Written by V. Loschiavo 
# Feb 12 2017
# Shutdown via button after three seconds
# Don't forget your pull up resistors (or use the internal pullups per the below:
# Initial idea taken from: https://github.com/AyMac/Pandoras-Box
#
# Adapted to use clock delay versus sleep from: https://www.arduino.cc/en/Tutorial/BlinkWithoutDelay
# 
# I put the following commands in rc.local before starting pianobar and patiobar
# gpio -g mode 6 in	# Sets pin mode to input
# gpio -g mode 6 up	# Sets internal pull-up resistor
# gpio-watch 6:switch	# Sets up an interrupt on pin 6 with the "switch" type (switch uses a 100ms (100000us) software debounce)
#
##################################################################


# User defined Variables:

# Interval at which the button needs to be held
INTERVAL=3

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

DISPLAYMESSAGE="${SCRIPTSBASEDIR}/DisplayLCDMessage.py"
PARSEANDWRITE2LCD="${SCRIPTSBASEDIR}/ParseAndWrite.py"

##################################################################
# Begin Main
##################################################################


# Get the current time in seconds since Epoch
PREVIOUSSECONDS=`date +%s`

# While the pin is pulled low (you are pressing the button), do some stuff
while [ $(gpio -g read 6) = 0 ]
do
	# Get the current time in seconds at the beginning of the loop
	CURRENTSECONDS=`date +%s`

	# If current time minus previous time through the loop is less then the interval then sleep
	if (("$CURRENTSECONDS" - "$PREVIOUSSECONDS" <= "$INTERVAL"))
	then
		sleep .1	# Added the sleep for 1/10th of a second to reduce clock cycles spent monitoring this pin

	# If the user has been holding the button for the interval (or longer) then shutdown
	else
		# Display shutdown message
		$DISPLAYMESSAGE "Shutting Down" "Now Goodbye"
		#pbstop
		sudo shutdown -h now		# Power off the Pi
	fi
	
done


# The user let go of the button
# Do something different with this button here like: Display a menu.
# Temporary Example - redraw LCD with Current Song and Artist (maybe change to alternate between Song Name and Station Name?)
$PARSEANDWRITE2LCD

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
		temphumid=`/home/vloschiavo/src/Adafruit_Python_DHT/examples/simpletest.py` && $DISPLAYMESSAGE $temphumid
		sleep 8
		$PARSEANDWRITE2LCD
	fi

	if [ $shortlong == "long" ]; then
		echo -n 'n' >> $CTLFILE
        	$DISPLAYMESSAGE "Skipping song" ""
	fi

	;;
	

16)	# Love / Ban Song
	if [ $shortlong == "short" ]; then
		# Get the song title and love the song
		echo -n '+' >> $CTLFILE
		songtitle=`sed -n '1p' $EPHEMERAL/pandoraout`;
        	$DISPLAYMESSAGE "Loving song:" "$songtitle"
	fi

	if [ $shortlong == "long" ]; then
		# Get the song title and ban the song
		echo -n '-' >> $CTLFILE
		songtitle=`sed -n '1p' $EPHEMERAL/pandoraout`;
        	$DISPLAYMESSAGE "Banning song:" "$songtitle"
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
		echo -n '^' >> $CTLFILE
		$DISPLAYMESSAGE "Resetting" "volume"
		sleep 1
		$PARSEANDWRITE2LCD
	fi

	;;
	
19)	# Play/Pause / Tired of Song
	if [ $shortlong == "short" ]; then
		echo -n 'p' >> $CTLFILE
		# Indicate the button was pressed then redraw the Now Playing screen
		($DISPLAYMESSAGE "Play/Pause" ""; sleep 2; $PARSEANDWRITE2LCD) &
	fi

	if [ $shortlong == "long" ]; then
		echo -n 't' >> $CTLFILE
       		$DISPLAYMESSAGE "Ban song" "for 1 month"
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
	
100)	# (BTN_0) Favorite Stations Shortcuts - Implemented for IR remote control
	# Favorite station: ZZ Top
	STATIONNUM=`grep -i "zz top" ${EPHEMERAL}/stationList | awk -F ":" '{print $1}'`
	STATIONNAME=`grep ^${STATIONNUM} ${EPHEMERAL}/stationList | awk -F ":" '{print $2}'`
	echo -n 's' >> $CTLFILE
	echo ${STATIONNUM} >> $CTLFILE
	$DISPLAYMESSAGE "New Station:" "$STATIONNAME"

	;;
	
101)	# (BTN_1) Favorite Stations Shortcuts - Implemented for IR remote control
	# Favorite station: Stevie Ray Vaughan
	STATIONNUM=`grep -i "Stevie Ray Vaughan" ${EPHEMERAL}/stationList | awk -F ":" '{print $1}'`
	STATIONNAME=`grep ^${STATIONNUM} ${EPHEMERAL}/stationList | awk -F ":" '{print $2}'`
	$DISPLAYMESSAGE "New Station:" "$STATIONNAME"
	echo -n 's' >> $CTLFILE
	echo ${STATIONNUM} >> $CTLFILE

	;;
	
102)	# (BTN_2) Favorite Stations Shortcuts - Implemented for IR remote control
	# Favorite station: Jazz  Radio
	STATIONNUM=`grep -i "Jazz  Radio" ${EPHEMERAL}/stationList | awk -F ":" '{print $1}'`
	STATIONNAME=`grep ^${STATIONNUM} ${EPHEMERAL}/stationList | awk -F ":" '{print $2}'`
	$DISPLAYMESSAGE "New Station:" "$STATIONNAME"
	echo -n 's' >> $CTLFILE
	echo ${STATIONNUM} >> $CTLFILE

	;;
	
103)	# (BTN_3) Favorite Stations Shortcuts - Implemented for IR remote control
	# Favorite station: Van Halen
	STATIONNUM=`grep -i "Van Halen" ${EPHEMERAL}/stationList | awk -F ":" '{print $1}'`
	STATIONNAME=`grep ^${STATIONNUM} ${EPHEMERAL}/stationList | awk -F ":" '{print $2}'`
	$DISPLAYMESSAGE "New Station:" "$STATIONNAME"
	echo -n 's' >> $CTLFILE
	echo ${STATIONNUM} >> $CTLFILE

	;;
	
104)	# (BTN_4) Favorite Stations Shortcuts - Implemented for IR remote control
	# Favorite station: Louisiana Blues
	STATIONNUM=`grep -i "Louisiana Blues" ${EPHEMERAL}/stationList | awk -F ":" '{print $1}'`
	STATIONNAME=`grep ^${STATIONNUM} ${EPHEMERAL}/stationList | awk -F ":" '{print $2}'`
	$DISPLAYMESSAGE "New Station:" "$STATIONNAME"
	echo -n 's' >> $CTLFILE
	echo ${STATIONNUM} >> $CTLFILE

	;;
	
105)	# (BTN_5) Favorite Stations Shortcuts - Implemented for IR remote control
	# Favorite station: John Coltrane
	STATIONNUM=`grep -i "John Coltrane" ${EPHEMERAL}/stationList | awk -F ":" '{print $1}'`
	STATIONNAME=`grep ^${STATIONNUM} ${EPHEMERAL}/stationList | awk -F ":" '{print $2}'`
	$DISPLAYMESSAGE "New Station:" "$STATIONNAME"
	echo -n 's' >> $CTLFILE
	echo ${STATIONNUM} >> $CTLFILE

	;;
	
106)	# (BTN_6) Favorite Stations Shortcuts - Implemented for IR remote control
	# Favorite station: Soundgarden Radio
	STATIONNUM=`grep -i "Soundgarden Radio" ${EPHEMERAL}/stationList | awk -F ":" '{print $1}'`
	STATIONNAME=`grep ^${STATIONNUM} ${EPHEMERAL}/stationList | awk -F ":" '{print $2}'`
	$DISPLAYMESSAGE "New Station:" "$STATIONNAME"
	echo -n 's' >> $CTLFILE
	echo ${STATIONNUM} >> $CTLFILE

	;;
	
107)	# (BTN_7) Favorite Stations Shortcuts - Implemented for IR remote control
	# Favorite station: Rock Guitar 
	STATIONNUM=`grep -i "Rock Guitar" ${EPHEMERAL}/stationList | awk -F ":" '{print $1}'`
	STATIONNAME=`grep ^${STATIONNUM} ${EPHEMERAL}/stationList | awk -F ":" '{print $2}'`
	$DISPLAYMESSAGE "New Station:" "$STATIONNAME"
	echo -n 's' >> $CTLFILE
	echo ${STATIONNUM} >> $CTLFILE

	;;
	
108)	# (BTN_8) Favorite Stations Shortcuts - Implemented for IR remote control
	# Favorite station: Miles Davis
	STATIONNUM=`grep -i "Miles Davis" ${EPHEMERAL}/stationList | awk -F ":" '{print $1}'`
	STATIONNAME=`grep ^${STATIONNUM} ${EPHEMERAL}/stationList | awk -F ":" '{print $2}'`
	$DISPLAYMESSAGE "New Station:" "$STATIONNAME"
	echo -n 's' >> $CTLFILE
	echo ${STATIONNUM} >> $CTLFILE

	;;
	
109)	# (BTN_9) Favorite Stations Shortcuts - Implemented for IR remote control
	# Favorite station: Master Of Puppets Radio
	STATIONNUM=`grep -i "Master Of Puppets Radio" ${EPHEMERAL}/stationList | awk -F ":" '{print $1}'`
	STATIONNAME=`grep ^${STATIONNUM} ${EPHEMERAL}/stationList | awk -F ":" '{print $2}'`
	$DISPLAYMESSAGE "New Station:" "$STATIONNAME"
	echo -n 's' >> $CTLFILE
	echo ${STATIONNUM} >> $CTLFILE

	;;
	
plus)	# (BTN_PREVIOUSSONG) Like song 
	echo -n '+' >> $CTLFILE
	SONGNAME=`awk 'NR==1{print}' ${EPHEMERAL}/pandoraout`
	$DISPLAYMESSAGE "Liking Song:" "$SONGNAME"

	;;
	
n)	# (BTN_NEXTSONG) Skip song 
	echo -n 'n' >> $CTLFILE
	SONGNAME=`awk 'NR==1{print}' ${EPHEMERAL}/pandoraout`
	$DISPLAYMESSAGE "Skipping Song:" "$SONGNAME"

	;;
	
P)	# (BTN_PLAYPAUSE) Play
	echo -n 'P' >> $CTLFILE
	SONGNAME=`awk 'NR==1{print}' ${EPHEMERAL}/pandoraout`
	$DISPLAYMESSAGE "Play:" "$SONGNAME"
	(sleep 3 && $PARSEANDWRITE2LCD) &
	
	;;
	
S)	# (BTN_PLAYPAUSE) Pause 
	echo -n 'S' >> $CTLFILE
	SONGNAME=`awk 'NR==1{print}' ${EPHEMERAL}/pandoraout`
	$DISPLAYMESSAGE "Paused:" "$SONGNAME"

	;;
	
audio)	# (BTN_AUDIO) Reset Volume 
	# Reset pianobar's volume
	echo -n '^' >> $CTLFILE 
	
	# Reset amixer volume
	amixer sset 'PCM' 95% > /dev/null
	$DISPLAYMESSAGE "Resetting Volume" ""
	(sleep 2 && $PARSEANDWRITE2LCD) &

	;;
	
esac

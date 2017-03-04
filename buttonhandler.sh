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
#	4		|	Tap=Redraw Now Playing 	/ Hold=Shutdown
#	12		|	Tap=Display Temp	/ Hold=Skip Track
#	22		|	Tap=Love song		/ Hold=Ban song
# 	18		|	Tap=Mute/Unmute		/ Hold=Return to sane volume level
#	23		|	Tap=Play/Pause		/ Hold=Tired of Song
#	24		|	Tap=Menu/Select		/ Hold=Go back
# -----------------------------------------------------------
#
# $1 = the GPIO pin triggered
# $2 = the value of the pin (0 || 1)
#
##################################################################

TRIGGEREDPIN=$1

# User defined Variables:

# Interval, in seconds, which the button needs to be held

if [ $TRIGGEREDPIN = 4 ]
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

. ${SCRIPTSBASEDIR}/config.sh

##################################################################
# Get Song Title Function
##################################################################
GETSONGTITLE() {
	songtitle=`sed -n '1p' $EPHEMERAL/pandoraout`;
}

##################################################################
# Ban Song Function
##################################################################

BANSONG() {
	# Get the song title and ban the song
	echo -n '-' >> $CTLFILE
	GETSONGTITLE
	$DISPLAYMESSAGE "Permanent Ban:" "$songtitle"
}

##################################################################
# Change Station Function
##################################################################
CHANGESTATION() {
	# Change stations - $1 = Station Name to grep 
	STATIONNUM=`grep -i "$1" ${EPHEMERAL}/stationList | awk -F ":" '{print $1}'`
	STATIONNAME=`grep ^${STATIONNUM} ${EPHEMERAL}/stationList | awk -F ":" '{print $2}'`
	echo -n 's' >> $CTLFILE
	sleep .5
	echo ${STATIONNUM} >> $CTLFILE
	$DISPLAYMESSAGE "New Station:" "$STATIONNAME"
}


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

4)	# Redraw / Shutdown Pin Pressed
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
		$SCRIPTSBASEDIR/TempHumidDisplay.sh
		sleep 8
		$PARSEANDWRITE2LCD
	fi

	if [ $shortlong == "long" ]; then
		echo -n 'n' >> $CTLFILE
        	$DISPLAYMESSAGE "Skipping song" ""
	fi

	;;
	

22)	# Love / Ban Song
	if [ $shortlong == "short" ]; then
		# Get the song title and love the song
		echo -n '+' >> $CTLFILE
		GETSONGTITLE
        	$DISPLAYMESSAGE "Loving song:" "$songtitle"
	fi

	if [ $shortlong == "long" ]; then
		BANSONG
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
	
23)	# Play/Pause / Tired of Song
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

24)	# Not implemented yet: Menu/Select  /   Go back
	if [ $shortlong == "short" ]; then
        	$DISPLAYMESSAGE "Menu" "Select"
	fi

	if [ $shortlong == "long" ]; then
       		$DISPLAYMESSAGE "Go" "Back"
	fi

	;;
	
100)	# (BTN_0) Favorite Stations Shortcuts - Implemented for IR remote control
	# Favorite station: ZZ Top
	CHANGESTATION "zz top"

	;;
	
101)	# (BTN_1) Favorite Stations Shortcuts - Implemented for IR remote control
	# Favorite station: Stevie Ray Vaughan
	CHANGESTATION "Stevie Ray Vaughan"
	;;
	
102)	# (BTN_2) Favorite Stations Shortcuts - Implemented for IR remote control
	# Favorite station: Jazz  Radio
	CHANGESTATION "Jazz  Radio"

	;;
	
103)	# (BTN_3) Favorite Stations Shortcuts - Implemented for IR remote control
	# Favorite station: Van Halen
	CHANGESTATION "Van Halen"

	;;
	
104)	# (BTN_4) Favorite Stations Shortcuts - Implemented for IR remote control
	# Favorite station: Louisiana Blues
	CHANGESTATION "Louisiana Blues"

	;;
	
105)	# (BTN_5) Favorite Stations Shortcuts - Implemented for IR remote control
	# Favorite station: John Coltrane
	CHANGESTATION "John Coltrane"

	;;
	
106)	# (BTN_6) Favorite Stations Shortcuts - Implemented for IR remote control
	# Favorite station: Soundgarden Radio
	CHANGESTATION "Soundgarden Radio"

	;;
	
107)	# (BTN_7) Favorite Stations Shortcuts - Implemented for IR remote control
	# Favorite station: Rock Guitar 
	CHANGESTATION "Rock Guitar"

	;;
	
108)	# (BTN_8) Favorite Stations Shortcuts - Implemented for IR remote control
	# Favorite station: Miles Davis
	CHANGESTATION "Miles Davis"

	;;
	
109)	# (BTN_9) Favorite Stations Shortcuts - Implemented for IR remote control
	# Favorite station: Master Of Puppets Radio
	CHANGESTATION "Master Of Puppets Radio"

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
	
ban)	# Reset pianobar's volume
	BANSONG

	;;
	
t)	# (KEY_FASTFORWARD) >> button 
	# Tired of song - pianobar to skip for 30 days
	echo -n 't' >> $CTLFILE 
	
	$DISPLAYMESSAGE "Banning song for" "30 Days"

	;;
	
pbstart) # (PBC) + (SD/USB) button 
	sudo -iu \#1000 /usr/local/bin/pbstart
	
	$DISPLAYMESSAGE "Starting" "vLo Radio"

	;;
	
pbstop) # (PBC) + (SD/USB) button 
	$DISPLAYMESSAGE "Shutting down" ""
	sudo -iu \#1000 /usr/local/bin/pbstop
	sudo poweroff

	;;
	
esac

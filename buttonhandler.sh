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
# Functions
##################################################################

# Get Song Title
GETSONGTITLE() {
	read -r songtitle < ${EPHEMERAL}/pandoraout
}

# Effect some song based action on pianobar (i.e. ban, love, skip, etc)
# $1=pianobar command letter ;  $2=Message to display on LCD line 1.  Line 2 will display the song title
SONGACTION() {
	echo -n "$1" >> $CTLFILE
	GETSONGTITLE
	$DISPLAYMESSAGE "$2" "$songtitle"	
}

# Change Station
CHANGESTATION() {
	# Change stations - $1 = Station Name to grep 
	STATIONNUM=`grep -i "$1" ${EPHEMERAL}/stationList | awk -F ":" '{print $1}'`
	STATIONNAME=`grep ^${STATIONNUM} ${EPHEMERAL}/stationList | awk -F ":" '{print $2}'`
	echo -n 's' >> $CTLFILE
	sleep .5
	echo ${STATIONNUM} >> $CTLFILE
	$DISPLAYMESSAGE "New Station:" "$STATIONNAME"
}

# Reset pianobar and alsa's volume levels
RESETAUDIO() {
	# Reset pianobar's volume
	echo -n '^' >> $CTLFILE 
	
	# Reset amixer volume
	amixer sset 'PCM' 95% > /dev/null
	$DISPLAYMESSAGE "Resetting Volume" ""
	(sleep 2 && $PARSEANDWRITE2LCD) &

}

# Stop all daemons and poweroff
POWEROFF() {
	$DISPLAYMESSAGE "Shutting down" "system"
	sudo -iu \#1000 /usr/local/bin/pbstop
	sudo poweroff

}



##################################################################
# Begin Main
##################################################################

# Determine if the button was a short or long press

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
		# Stop everything
		POWEROFF
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
		SONGACTION "+" "Loving song"
	fi

	if [ $shortlong == "long" ]; then
		SONGACTION "-" "Banning song"
	fi

	;;
	

18)	# Mute/Unmute toggle / Return to default volume level
	if [ $shortlong == "short" ]; then

		# Toggle the mute button and store the output in variable $mute
		mute=`amixer set PCM toggle`

		if [[ $mute =~ \[on\] ]]
		then 
			($DISPLAYMESSAGE "Mute is" "Off"; sleep 1.5; $PARSEANDWRITE2LCD) &
		fi

		if [[ $mute =~ \[off\] ]]
		then 
			($DISPLAYMESSAGE "Mute is" "On") &
		fi
        	
	fi

	if [ $shortlong == "long" ]; then
		# Reset all audio to default levels
		RESETAUDIO
	fi

	;;
	
23)	# Play/Pause / Tired of Song
	if [ $shortlong == "short" ]; then
		SONGACTION "p" "Play/Pause"
		# Indicate the button was pressed then redraw the Now Playing screen
		(sleep 2; $PARSEANDWRITE2LCD) &
	fi

	if [ $shortlong == "long" ]; then
		SONGACTION "t" "Ban for 1 month:"
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
	
plus)	# (BTN_PREVIOUSSONG) Love song
	SONGACTION "+" "Love song:"
	(sleep 3 && $PARSEANDWRITE2LCD) &

	;;
	
n)	# (BTN_NEXTSONG) Skip song 
	SONGACTION "n" "Skip song:"

	;;
	
P)	# (BTN_PLAYPAUSE) Play
	SONGACTION "P" "Play:"
	(sleep 3 && $PARSEANDWRITE2LCD) &
	
	;;
	
S)	# (BTN_PLAYPAUSE) Pause 
	SONGACTION "S" "Paused:"

	;;
	
audio)	# (BTN_AUDIO) Reset Volume
	RESETAUDIO

	;;
	
ban)	# Bansong
	SONGACTION "-" "Ban song:"

	;;
	
t)	# (KEY_FASTFORWARD) >> button 
	# Tired of song - pianobar to skip for 30 days
	SONGACTION "t" "Ban for 1 month:"

	;;
	
pbstart) # (PBC) + (SD/USB) button 
	# Startup vloradio
	sudo -iu \#1000 /usr/local/bin/pbstart

	;;
	
pbstop) # (PBC) + (Setup) button 
	# Stop vloradio
	$DISPLAYMESSAGE "Stopping" "Pianobar"
	sudo -iu \#1000 /usr/local/bin/pbstop

	;;
	
poweroff) # (PBC) + (Power) button
	POWEROFF

	;;
	
INPUT) # (Input) button
	# Display CPU and GPU Temps

	# Get the GPU Temp
	GPUTEMP=`vcgencmd measure_temp | cut -d"=" -f2 | cut -f1 -d"'"`

	# Get the CPU Temp and format it
	CPUTEMP=$(</sys/class/thermal/thermal_zone0/temp)
	CPUTEMP=$(echo ${CPUTEMP::-3}.${CPUTEMP:2:1})

	# Check for high temp
	if [ `echo $GPUTEMP | cut -d"." -f1` -gt 45 ] || [ `echo $CPUTEMP | cut -d"." -f1` -gt 45 ]
	then
		$DISPLAYMESSAGE "Temp High!!!" "C:${CPUTEMP}C G:${GPUTEMP}C"
	else
		$DISPLAYMESSAGE "CPU Temp: ${CPUTEMP}C" "GPU Temp: ${GPUTEMP}C"
		(sleep 6; $PARSEANDWRITE2LCD) &
	fi

	;;
esac

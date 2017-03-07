#!/bin/bash

# Cron script to check for high temperatures on the raspberry pi's CPU and GPU and shutdown if necessary


DISPLAYMESSAGE='/home/vloschiavo/src/vloradio/DisplayLCDMessage.py'

# Display CPU and GPU Temps

# Get the GPU Temp
GPUTEMP=`vcgencmd measure_temp | cut -d"=" -f2 | cut -f1 -d"'"`

# Get the CPU Temp and format it
CPUTEMP=$(</sys/class/thermal/thermal_zone0/temp)
CPUTEMP=$(echo ${CPUTEMP::-3}.${CPUTEMP:2:1}) 

# Check for high temp
if [ `echo $GPUTEMP | cut -d"." -f1` -gt 50 ] || [ `echo $CPUTEMP | cut -d"." -f1` -gt 50 ]
then
	if [ `echo $GPUTEMP | cut -d"." -f1` -gt 50 ]
	then
		$DISPLAYMESSAGE "GPU High:${GPUTEMP}" "Shutdown now"
		echo "SHUTDOWN NOW"
		sudo -iu \#1000 /usr/local/bin/pbstop
		sudo poweroff
	else
		$DISPLAYMESSAGE "CPU High:${CPUTEMP}" "Shutdown now"
		echo "SHUTDOWN NOW"
		sudo -iu \#1000 /usr/local/bin/pbstop
		sudo poweroff
	fi
fi

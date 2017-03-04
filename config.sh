#!/bin/bash

# Created by Vince Loschiavo for the vloradio project
# These are the environment variables needed for all the scripts to work nicely.

# This is the directory you cloned the git repo to:  https://github.com/vloschiavo/vloradio
export SCRIPTSBASEDIR="/home/vloschiavo/src/vloradio"

# Ephemeral storage directory - I use TMPFS (ramdrive) storage for this to reduce wear leveling of the microSD card on Raspberry Pi
# Various housekeeping files are stored here, like the FIFO for pianobar controls, Station List, and Current Song Title & Artist.
export EPHEMERAL="/var/tmp"

# FIFO for pianobar controls: Pianobar: https://github.com/PromyLOPh/pianobar
export CTLFILE="${EPHEMERAL}/ctl"

# Location of Patiobar: https://github.com/kylejohnson/Patiobar
export PATIOBAR="/home/vloschiavo/src/Patiobar"

# The script that writes to Character LCDs
DISPLAYMESSAGE="${SCRIPTSBASEDIR}/DisplayLCDMessage.py"

# Rewrites the "Now Playing" Screen to the display - Current Song Title & Artist
PARSEANDWRITE2LCD="${SCRIPTSBASEDIR}/ParseAndWrite.py"

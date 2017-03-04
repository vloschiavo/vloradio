# vloradio

Note: The lcd Menu is *not* working and is still a work in progress.  All other functions work as designed.  Please file bug reports.

Notes: This is not meant to be a step-by-step install guide.  If you need help installing any of these components google is your friend - that's how I installed them. :)


Lots of Prerequisites:

Hardware used:
-Raspberry Pi 2 or newer to support node.js for the web front end.  This project can easily be built with an older Raspberry Pi (1/B+/etc) without the web frontend/Patiobar
-Character LCD - I used a Parallel 16x2 LCD (2k Ohm Pot, 10k Ohm Pot, 2x 470uF Capacitor - The code could easily be adapted to an I2C LCD, Serial LCD, Nokia 5110, etc.  Simply replace the DisplayLCDMessage.py/ParseAndWrite.py with one of your making.
-DHT22 - Temperature and Humidty sensor (for fun)
-Rotary Encoder - To control the Volume
-Infrared Sensor and Remote
-6x Physical buttons (Momentary and normally open (NO)) (You can adapt the code to work with normally closed (NC) buttons as well).
-Solder/Iron/Hot glue/Homemade case/Dremel/screwdriver/and other miscellany.
-See the Fritzing diagram for the wiring diagram

Software used:
-Raspbian: Raspbian GNU/Linux 8 (jessie)
-lirc
-gnu screen
-Python 2.7.9
-Pianobar:  Install from source to get the latest version: https://github.com/PromyLOPh/pianobar/blob/master/INSTALL
-Patiobar:  https://github.com/kylejohnson/Patiobar
-Wiring Pi - http://wiringpi.com/
-GPIO-Watch - https://github.com/larsks/gpio-watch - Easy interrupt based buttons
-Adafruit_Python_CharLCD library: https://github.com/adafruit/Adafruit_Python_CharLCD
-Adafruit_Python_DHT library: https://github.com/adafruit/Adafruit_Python_DHT

Setup:

As your user (not root):
cd
mkdir src
cd src
git clone https://github.com/vloschiavo/vloradio
cd vloradio

I've made the assumption that you are using the default user named 'pi' at uid 1000 and and gid 1000. If you've create another user you'll want to search through the repo and look for #1000 and change it to your UID.

Beyond installing the above prerequisites and cloning this github repo: git clone https://github.com/vloschiavo/vloradio, you will need to modify a few files and settings.

rc.local:  This is used to kickstart all the processes. See the section at the bottom of the the enclosed sample rc.local - edit your /etc/rc.local with the editor of your choice as root: i.e. sudo vi /etc/rc.local

Add this before the exit 0 at the end of the file:

#########################################################
# Setup Environment and Start Patiobar / pianobar

export FIRSTBOOT=1
export SCRIPTSBASEDIR="/home/vloschiavo/src/vloradio"
. ${SCRIPTSBASEDIR}/config.sh

# Start up message
sudo -iu \#1000 ${SCRIPTSBASEDIR}/startupdisplay.sh &
sudo -iu \#1000 /usr/local/bin/pbstart &
#########################################################

exit 0

Edit the config.sh file to your paths. Other scripts source their configs from config.sh

Suggestion:  Make use of tmpfs to reduce wear on your SD card.  Everytime pianobar changes song, eventcmd writes to a file current data on the song.  I use tmpfs (ramdrive) to save the SD card writes.

Example:
/etc/fstab
#TMPFS
tmpfs   /var/lib/sudo           tmpfs           defaults,noatime,nosuid,mode=0755,size=2m       0 0
tmpfs   /var/spool/mqueue       tmpfs           defaults,noatime,nosuid,mode=0700,gid=12,size=30m       0 0
tmpfs   /var/log                tmpfs           defaults,noatime,nosuid,mode=0755,size=100m     0 0
tmpfs   /var/tmp                tmpfs           defaults,noatime,nosuid,size=30m                0 0


Also disable and remove swap:
dphys-swapfile swapoff
sudo apt remove dphys-swapfile

Edit:
/etc/default/tmpfs

RAMLOCK=yes
RAMSHM=no
RAMTMP=yes
TMPFS_SIZE=20%VM
RUN_SIZE=10%
LOCK_SIZE=5242880 # 5MiB
SHM_SIZE=10M
TMP_SIZE=25M


Edit index.js of patiobar to move files to the /var/tmp - you should just be able to drop in the index.js included in this repo as a replacement.

edit the file called "pianobar.config" with your username, password, default station, etc and copy it to pianobar's configuration directory.
vi pianobar.config
cp pianobar.config ~/.config/pianobar/

LIRC and IREXEC
You'll need to setup a remote control per lirc's instructions.  
For raspberry pi, you'll need to edit your /boot/config.txt to include this near the end:  This sets up the kernel module to receive signals and send to lircd
# Add support for LIRC over GPIO (BCM) Pins
dtoverlay=lirc-rpi,gpio_in_pin=27,gpio_in_pull=up

A good tutorial is here: but ignore the part about editing /etc/modules.  With the latest versions of raspbian and the above edit to /boot/config.txt this isn't needed.
http://alexba.in/blog/2013/01/06/setting-up-lirc-on-the-raspberrypi/

And here's how to create an lircd.conf for your remote:
https://www.solihull-web-design.com/blog/how-setup-lirc-gpio-ir-remote-control-openelec-xbmckodi-raspberry-pi-1-and-2 (start at step 6)

Additionally you'll need to setup some softlinks to the button handler
ln -s /home/pi/src/vloradio/buttonhandler.sh /etc/gpio-scripts/4
ln -s /home/pi/src/vloradio/buttonhandler.sh /etc/gpio-scripts/12
ln -s /home/pi/src/vloradio/buttonhandler.sh /etc/gpio-scripts/22
ln -s /home/pi/src/vloradio/buttonhandler.sh /etc/gpio-scripts/18
ln -s /home/pi/src/vloradio/buttonhandler.sh /etc/gpio-scripts/23
ln -s /home/pi/src/vloradio/buttonhandler.sh /etc/gpio-scripts/24



Here is a brief summary of all the pins used:

Button GPIO PINs:
4
12
22
18
23
24

Rotary Encoder GPIO PINs:
17 
5

DHT GPIO PIN:
25

LCD GPIO PINs:
6
13
21
16
19
20
26

Usage:
Plug in, and turn on.

The RPi will boot and start a gnu screen session called "pianobar" and start pianobar in screen 0, and patiobar in screen 1
Messages will be displayed on the LCD as to the current status during the boot process:
i.e. Booting, starting pianobar, etc.

Once booted pianobar will start playing and display the currently playing song data on the LCD (Line 1: Artist, Line 2: Song Title)

You can then use the physical buttons and the IR remote control to control various tasks: Show the temperature & humidity, read the CPU temp, pause, play, mute, volume, like, change stations, etc.

Take a close look at the included lircd.conf and lircrc for examples of things you can do with the remote.  lircd detects button presses, irexec/lircrc call the buttonhandler.sh and perform various tasks.  Feel free to customize for your needs and remote.  In the included lircrc I've included a "Power Mode".  I didn't want to accidentally press the power button on the remote and have the whole Pi shutdown by mistake.  Therefore I use another button to toggle into and out of a different mode (Power) that then enables the poweroff, pbstart, pbstop buttons).  Those buttons are disabled in the normal/default mode.

In the future I'll be adding a LCD menu system that can be driven by the physical buttons and the remote (work in progress).



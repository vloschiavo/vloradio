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



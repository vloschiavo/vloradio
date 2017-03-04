#!/usr/bin/python

# Created by V. Loschiavo
# Inspired by: https://github.com/AyMac/Pandoras-Box

#Read the file output from eventcmd.sh in the PANDORAOUT file created by eventcmd.sh
#and print to the LCD Display

# Import sys and os modules to support reading of files and environment variables
import sys
import os

# File to read the pandora/pianobar Song Title, Artist, and Station Name
PANDORAOUT=(os.getenv("EPHEMERAL", "/var/tmp")+ "/pandoraout")


# To Do: Change this to be an import DisplayLCDMessage

# Import the Adafruit library: https://github.com/adafruit/Adafruit_Python_CharLCD
import Adafruit_CharLCD as LCD

# LCD/Raspberry Pi pin configuration:
lcd_rs        = 26
lcd_en        = 20
lcd_d4        = 19
lcd_d5        = 13
lcd_d6        = 21
lcd_d7        = 16
lcd_backlight = 6

# Define LCD column and row size for 16x2 LCD.
lcd_columns = 16
lcd_rows    = 2

# Start the LCD:
lcd = LCD.Adafruit_CharLCD(lcd_rs, lcd_en, lcd_d4, lcd_d5, lcd_d6, lcd_d7, lcd_columns, lcd_rows, lcd_backlight)

# Clear the LCD in case something else has updated it
#lcd.clear()

#Open the file
f=open(PANDORAOUT, 'r')


# Change this to a for loop and loop through LCD rows and lines in the file
# Read the first line and store it in song
song = f.readline()

# Read the second line and store it in artist
artist = f.readline()

# Third line is Station Name
#station = f.readline()

lcd.message(artist)
lcd.message(song)
#lcd.message(station)
f.close()

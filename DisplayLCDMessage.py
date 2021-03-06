#!/usr/bin/python

# Created by V. Loschiavo
# Feb 15, 2017
# Inspired by: https://github.com/AyMac/Pandoras-Box

# This is a utility script to display any message (from the command line arguments) on the LCD Display
# Usage ./DisplayLCDMessage.py "Line 1 text" "Line 2 Text"
# Any message longer than your display will just go off the edge of the display (no word wrapping)

# Prereqs: Adafruit library: 
# git clone https://github.com/adafruit/Adafruit_Python_CharLCD

def main(arguments = []):
  # Import the Adafruit library
  import Adafruit_CharLCD as LCD
  
  # LCD/Raspberry Pi pin configuration (Using the Broadcom Pin Numbers):
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
 
  #Degree Symbol
  lcd.create_char(1, [7,5,7,0,0,0,0,0]);
 
  # Clear the LCD before writing to it
  #lcd.clear()
  
  # Loop through the lines and command line argument and print on each line (additional command line arguments will be ignored)
  for i in range(0,lcd_rows):
      # Move the cursor to each line of the LCD
      lcd.set_cursor(0, i)
      
      # Print the message from the command line argv to the line
      lcd.message(arguments[i+1])


'''
  # Decode string escape to read escape characters:
  lcd.message(sys.argv[3].decode('string-escape'))
  # Degrees C
  lcd.create_char(1, [0,24,24,3,4,4,4,3])
  
  # Heart
  lcd.create_char(2, [0,0,10,31,31,14,4,0]);
  
  # Dot
  lcd.create_char(3, [0,4,10,17,17,10,4,0]);
  
  #Degree Symbol
  lcd.create_char(4, [7,5,7,0,0,0,0,0]);
   
  lcd.clear();
  #lcd.backlight(lcd.colors.RED);
  #lcd.message('I \x02 n\x03de.js\n');
  #lcd.message('The temp is 22\x04C ');

  message=('The temp is 22\x04C');
  lcd.message(message);
 
  bogusarray = []
  bogusarray.append("The temp is 22\x04C");
  lcd.message(bogusarray[0]);
'''

if __name__ == "__main__":
  
  # Import sys module to support reading commandline arguments (argv)
  import sys
  #print(sys.argv[3].decode('string-escape'))
  main(sys.argv)


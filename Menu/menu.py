#!/usr/bin/python
#
# Created by Alan Aufderheide, February 2013 - https://github.com/aufder/RaspberryPiLcdMenu
# 
# Modified by Vince Loschiavo
# Feb 17 2017 - Changed to support pianobar, the adafruit python charlcd (https://github.com/adafruit/Adafruit_Python_CharLCD) library (vs the I2C LCD library)
# git clone https://github.com/vloschiavo/vloradio.git
# 
# This code is also adapted to use a single button and a digital encoder for menu selection
#
# This script provides a menu driven application using a parallel LCD, digital encoder, and a button  
# Support adafruit.com!

import commands
import os
from string import split
from time import sleep, strftime, localtime
import time
from datetime import datetime, timedelta
from xml.dom.minidom import *
import Adafruit_CharLCD as LCD
from ListSelector import ListSelector
import RPi.GPIO as GPIO
from Queue import Queue

# Define the Broadcom GPIO numbering to define to which pins you've hooked up your digital encoder:
# Channel A is one side of the three pins, channel b is the other side.  The middle pin goes to ground.
# Channel C is the push button
channelA = 13
channelB = 5
channelC = 16
q = Queue()

configfile = 'lcdmenu.xml'
# set DEBUG=1 for print debug statements
DEBUG = 1

# LCD/Raspberry Pi pin configuration (Using the Broadcom Pin Numbers):
lcd_rs        = 25
lcd_en        = 24
lcd_d4        = 23
lcd_d5        = 17
lcd_d6        = 21
lcd_d7        = 22
lcd_backlight = 4

# Define LCD column and row size for 16x2 LCD.
lcd_columns = 16
lcd_rows    = 2

# set to 0 if you want the LCD to stay on, 1 to turn off and on auto
AUTO_OFF_LCD = 0

# in case you add custom logic to lcd to check if it is connected (useful)
#if lcd.connected == 0:
#    quit()

# Start the LCD:
lcd = LCD.Adafruit_CharLCD(lcd_rs, lcd_en, lcd_d4, lcd_d5, lcd_d6, lcd_d7, lcd_columns, lcd_rows, lcd_backlight)

# Clear the LCD before writing to it
#lcd.clear()

# Hmmm...interesting.  May implement this later
#lcd.backlight(lcd.OFF)

# Create custom characters to display on the LCD 
#Degree Symbol
lcd.create_char(1, [7,5,7,0,0,0,0,0]);

# Clockwise Arrow
#lcd.create_char(2, [0,15,3,5,9,16,16,16]);
lcd.create_char(2, [0,15,3,5,9,8,8,6]);

# Anticlockwise Arrow
#lcd.create_char(3, [0,30,24,20,18,1,1,1]);
lcd.create_char(3, [0,30,24,20,18,2,2,4]);

#Use this to display special the characters above: 
#lcd.message('The temp is 22\x01C ');

# Rotary Encoder and Push button handler setup
def RotaryEncoderGPIObutton():
    if DEBUG: 
        print("In RotaryEncoderGPIObutton()")

    GPIO.setmode(GPIO.BCM)
    GPIO.setwarnings(False)
 
    # Define the pins as inputs and use the internal pull-up resistors
    GPIO.setup(channelA, GPIO.IN, pull_up_down=GPIO.PUD_UP)
    GPIO.setup(channelB, GPIO.IN, pull_up_down=GPIO.PUD_UP)
    GPIO.setup(channelC, GPIO.IN, pull_up_down=GPIO.PUD_UP)
    
    # Use interrupts to detect pin changes - this saves us from having to poll the pins in a loop
    # the GPIO.BOTH setting detects both the rising and falling edges 
    GPIO.add_event_detect(channelA, GPIO.BOTH, callback=roll_callback)
    GPIO.add_event_detect(channelB, GPIO.BOTH, callback=roll_callback)
    GPIO.add_event_detect(channelC, GPIO.FALLING, callback=push_callback, bouncetime=300)
 
    prev_pos = 0;
    if GPIO.input(channelA) == False:
        prev_pos |= 1 << 0
    if GPIO.input(channelB) == False:
        prev_pos |= 1 << 1
    q.put((prev_pos, 0))
 
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        pass
    GPIO.cleanup()

def roll_callback(channel):
    global action
    action = 0 # 1 or -1 if moved, sign is direction
    cur_pos = 0
    
    if GPIO.input(channelA) == False:
        cur_pos |= 1 << 0
    if GPIO.input(channelB) == False:
        cur_pos |= 1 << 1

    item = q.get()
    prev_pos = item[0]
    flags = item[1]
    if cur_pos != prev_pos:
        if prev_pos == 0x00:
            # this is the first edge
            if cur_pos == 0x01:
                flags |= 1 << 0
            elif cur_pos == 0x02:
                flags |= 1 << 1
        if cur_pos == 0x03:
            # this is when the encoder is in the middle of a "step"
            flags |= 1 << 4
        elif cur_pos == 0x00:
            # this is the final edge
            if prev_pos == 0x02:
                flags |= 1 << 2
            elif prev_pos == 0x01:
                flags |= 1 << 3
 
            # check the first and last edge
            # or maybe one edge is missing, if missing then require the middle state
            # this will reject bounces and false movements
            if flags & 1 << 0 > 0 and (flags & 1 << 2 > 0 or flags & 1 << 4 > 0):
                action = 1
            elif flags & 1 << 2 > 0 and (flags & 1 << 0 > 0 or flags & 1 << 4 > 0):
                action = 1
            elif flags & 1 << 1 > 0 and (flags & 1 << 3 > 0 or flags & 1 << 4 > 0):
                action = -1
            elif flags & 1 << 3 > 0 and (flags & 1 << 1 > 0 or flags & 1 << 4 > 0):
                action = -1
            flags = 0

        # If the knob turned clockwise turn up the volume
        if action > 0:
            if DEBUG:
                print ('in roll_callback - Clockwise'); 
   
        # If the knob turned counter-clockwise (anti-clockwise) turn down the volume
        elif action < 0:
            if DEBUG:
                print ('in roll_callback - Anticlockwise'); 
 
    q.put((cur_pos, flags))

# If you pushed the button (channelC)
def push_callback(channel):
    if GPIO.input(channel) == False:
        if DEBUG:
            print ('Push');
        global buttonPressed
        buttonPressed = 1

# commands
def DoQuit():
    lcd.clear()
    # Print Are you sure? Turn clockwise for Y
    lcd.message('Are you sure?\nTurn \x02 for Y')
    while 1:
	# Change this to if anticlockwise ( and repeat for all actions below )
        if action < 0:
            break
	# Change this to if clockwise
        if action > 0:
            lcd.clear()
            #lcd.backlight(lcd.OFF)
            if DEBUG:
                print("Quit selected");
            quit()
        sleep(0.25)

def DoShutdown():
    lcd.clear()
    # Print Are you sure? Turn clockwise for Y
    lcd.message('Are you sure?\nTurn \x02 for Y')
    while 1:
        if action < 0:
            break
        if action > 0:
            lcd.clear()
            #lcd.backlight(lcd.OFF)
            #commands.getoutput("sudo shutdown -h now")
            if DEBUG:
                print("Shutdown selected");
            quit()
        sleep(0.25)

def DoReboot():
    lcd.clear()
    # Print Are you sure? Turn clockwise for Y
    lcd.message('Are you sure?\nTurn \x02 for Y')
    while 1:
        if action < 0:
            break
        if action > 0:
            lcd.clear()
            #lcd.backlight(lcd.OFF)
            #commands.getoutput("sudo reboot")
            if DEBUG:
                print("Reboot selected");
            quit()
        sleep(0.25)

def LcdOff():
    if DEBUG:
        print('in LcdOff')
    #global currentLcd
    #currentLcd = lcd.OFF
    #lcd.backlight(currentLcd)

def LcdOn():
    if DEBUG:
        print('in LcdOn')
    #global currentLcd
    #currentLcd = lcd.ON
    #lcd.backlight(currentLcd)

def LcdRed():
    if DEBUG:
        print('in LcdRed')
    #global currentLcd
    #currentLcd = #lcd.RED
    #lcd.backlight(currentLcd)

def LcdGreen():
    if DEBUG:
        print('in LcdGreen')
    #global currentLcd
    #currentLcd = #lcd.GREEN
    #lcd.backlight(currentLcd)

def LcdBlue():
    if DEBUG:
        print('in LcdBlue')
    #global currentLcd
    #currentLcd = #lcd.BLUE
    #lcd.backlight(currentLcd)

def LcdYellow():
    if DEBUG:
        print('in LcdYellow')
    #global currentLcd
    #currentLcd = lcd.YELLOW
    #lcd.backlight(currentLcd)

def LcdTeal():
    if DEBUG:
        print('in LcdTeal')
    #global currentLcd
    #currentLcd = lcd.TEAL
    #lcd.backlight(currentLcd)

def LcdViolet():
    if DEBUG:
        print('in LcdViolet')
    #global currentLcd
    #currentLcd = lcd.VIOLET
    #lcd.backlight(currentLcd)

def ShowDateTime():
    if DEBUG:
        print('in ShowDateTime')
    lcd.clear()
    while not(buttonPressed):
        sleep(0.25)
        lcd.home()
        lcd.message(strftime('%a %b %d %Y\n%I:%M:%S %p', localtime()))
    
def ValidateDateDigit(current, curval):
    # do validation/wrapping
    if current == 0: # Mm
        if curval < 1:
            curval = 12
        elif curval > 12:
            curval = 1
    elif current == 1: #Dd
        if curval < 1:
            curval = 31
        elif curval > 31:
            curval = 1
    elif current == 2: #Yy
        if curval < 1950:
            curval = 2050
        elif curval > 2050:
            curval = 1950
    elif current == 3: #Hh
        if curval < 0:
            curval = 23
        elif curval > 23:
            curval = 0
    elif current == 4: #Mm
        if curval < 0:
            curval = 59
        elif curval > 59:
            curval = 0
    elif current == 5: #Ss
        if curval < 0:
            curval = 59
        elif curval > 59:
            curval = 0
    return curval

'''
def SetDateTime():
    if DEBUG:
        print('in SetDateTime')
    # M D Y H:M:S AM/PM
    curtime = localtime()
    month = curtime.tm_mon
    day = curtime.tm_mday
    year = curtime.tm_year
    hour = curtime.tm_hour
    minute = curtime.tm_min
    second = curtime.tm_sec
    ampm = 0
    if hour > 11:
        hour -= 12
        ampm = 1
    curr = [0,0,0,1,1,1]
    curc = [2,5,11,1,4,7]
    curvalues = [month, day, year, hour, minute, second]
    current = 0 # start with month, 0..14

    lcd.clear()
    lcd.message(strftime("%b %d, %Y  \n%I:%M:%S %p  ", curtime))
    lcd.blink()
    lcd.setCursor(curc[current], curr[current])
    sleep(0.5)
    while 1:
        curval = curvalues[current]
        if lcd.buttonPressed(lcd.UP):
            curval += 1
            curvalues[current] = ValidateDateDigit(current, curval)
            curtime = (curvalues[2], curvalues[0], curvalues[1], curvalues[3], curvalues[4], curvalues[5], 0, 0, 0)
            lcd.home()
            lcd.message(strftime("%b %d, %Y  \n%I:%M:%S %p  ", curtime))
            lcd.setCursor(curc[current], curr[current])
        if lcd.buttonPressed(lcd.DOWN):
            curval -= 1
            curvalues[current] = ValidateDateDigit(current, curval)
            curtime = (curvalues[2], curvalues[0], curvalues[1], curvalues[3], curvalues[4], curvalues[5], 0, 0, 0)
            lcd.home()
            lcd.message(strftime("%b %d, %Y  \n%I:%M:%S %p  ", curtime))
            lcd.setCursor(curc[current], curr[current])
        if lcd.buttonPressed(lcd.RIGHT):
            current += 1
            if current > 5:
                current = 5
            lcd.setCursor(curc[current], curr[current])
        if lcd.buttonPressed(lcd.LEFT):
            current -= 1
            if current < 0:
                lcd.noBlink()
                return
            lcd.setCursor(curc[current], curr[current])
        if lcd.buttonPressed(lcd.SELECT):
            # set the date time in the system
            lcd.noBlink()
            os.system(strftime('sudo date --set="%d %b %Y %H:%M:%S"', curtime))
            break
        sleep(0.25)

    lcd.noBlink()
'''
def ShowIPAddress():
    if DEBUG:
        print('in ShowIPAddress')
    lcd.clear()
    lcd.message(commands.getoutput("/sbin/ifconfig").split("\n")[1].split()[1][5:])
    while 1:
        if buttonPressed:
            break
        sleep(0.25)

def ShowLatLon():
    if DEBUG:
        print('in ShowLatLon')

def SetLatLon():
    if DEBUG:
        print('in SetLatLon')
    
def SetLocation():
    if DEBUG:
        print('in SetLocation')
    global lcd
    list = []
    # coordinates usable by ephem library, lat, lon, elevation (m)
    list.append(['New York', '40.7143528', '-74.0059731', 9.775694])
    list.append(['Paris', '48.8566667', '2.3509871', 35.917042])
    selector = ListSelector(list, lcd)
    item = selector.Pick()
    # do something useful
    if (item >= 0):
        chosen = list[item]

def CompassGyroViewAcc():
    if DEBUG:
        print('in CompassGyroViewAcc')

def CompassGyroViewMag():
    if DEBUG:
        print('in CompassGyroViewMag')

def CompassGyroViewHeading():
    if DEBUG:
        print('in CompassGyroViewHeading')

def CompassGyroViewTemp():
    if DEBUG:
        print('in CompassGyroViewTemp')

def CompassGyroCalibrate():
    if DEBUG:
        print('in CompassGyroCalibrate')
    
def CompassGyroCalibrateClear():
    if DEBUG:
        print('in CompassGyroCalibrateClear')
    
def TempBaroView():
    if DEBUG:
        print('in TempBaroView')

def TempBaroCalibrate():
    if DEBUG:
        print('in TempBaroCalibrate')
    
def AstroViewAll():
    if DEBUG:
        print('in AstroViewAll')

def AstroViewAltAz():
    if DEBUG:
        print('in AstroViewAltAz')
    
def AstroViewRADecl():
    if DEBUG:
        print('in AstroViewRADecl')

def CameraDetect():
    if DEBUG:
        print('in CameraDetect')
    
def CameraTakePicture():
    if DEBUG:
        print('in CameraTakePicture')

def CameraTimeLapse():
    if DEBUG:
        print('in CameraTimeLapse')

class CommandToRun:
    def __init__(self, myName, theCommand):
        self.text = myName
        self.commandToRun = theCommand
    def Run(self):
        self.clist = split(commands.getoutput(self.commandToRun), '\n')
        if len(self.clist) > 0:
            lcd.clear()
            lcd.message(self.clist[0])
            for i in range(1, len(self.clist)):
                while 1:
                    if buttonPressed:
                        break
                    sleep(0.25)
                lcd.clear()
                lcd.message(self.clist[i-1]+'\n'+self.clist[i])          
                sleep(0.5)
        while 1:
            if buttonPressed:
                break

class Widget:
    def __init__(self, myName, myFunction):
        self.text = myName
        self.function = myFunction
        
class Folder:
    def __init__(self, myName, myParent):
        self.text = myName
        self.items = []
        self.parent = myParent

def HandleSettings(node):
    global lcd
    if node.getAttribute('lcdColor').lower() == 'red':
        LcdRed()
    elif node.getAttribute('lcdColor').lower() == 'green':
        LcdGreen()
    elif node.getAttribute('lcdColor').lower() == 'blue':
        LcdBlue()
    elif node.getAttribute('lcdColor').lower() == 'yellow':
        LcdYellow()
    elif node.getAttribute('lcdColor').lower() == 'teal':
        LcdTeal()
    elif node.getAttribute('lcdColor').lower() == 'violet':
        LcdViolet()
    elif node.getAttribute('lcdColor').lower() == 'white':
        LcdOn()
    if node.getAttribute('lcdBacklight').lower() == 'on':
        LcdOn()
    elif node.getAttribute('lcdBacklight').lower() == 'off':
        LcdOff()

def ProcessNode(currentNode, currentItem):
    children = currentNode.childNodes

    for child in children:
        if isinstance(child, xml.dom.minidom.Element):
            if child.tagName == 'settings':
                HandleSettings(child)
            elif child.tagName == 'folder':
                thisFolder = Folder(child.getAttribute('text'), currentItem)
                currentItem.items.append(thisFolder)
                ProcessNode(child, thisFolder)
            elif child.tagName == 'widget':
                thisWidget = Widget(child.getAttribute('text'), child.getAttribute('function'))
                currentItem.items.append(thisWidget)
            elif child.tagName == 'run':
                thisCommand = CommandToRun(child.getAttribute('text'), child.firstChild.data)
                currentItem.items.append(thisCommand)

class Display:
    def __init__(self, folder):
        self.curFolder = folder
        self.curTopItem = 0
        self.curSelectedItem = 0
    def display(self):
        if self.curTopItem > len(self.curFolder.items) - lcd_rows:
            self.curTopItem = len(self.curFolder.items) - lcd_rows
        if self.curTopItem < 0:
            self.curTopItem = 0
        if DEBUG:
            print('------------------')
        str = ''
        for row in range(self.curTopItem, self.curTopItem+lcd_rows):
            if row > self.curTopItem:
                str += '\n'
            if row < len(self.curFolder.items):
                if row == self.curSelectedItem:
                    cmd = '-'+self.curFolder.items[row].text
                    if len(cmd) < 16:
                        for row in range(len(cmd), 16):
                            cmd += ' '
                    if DEBUG:
                        print('|'+cmd+'|')
                    str += cmd
                else:
                    cmd = ' '+self.curFolder.items[row].text
                    if len(cmd) < 16:
                        for row in range(len(cmd), 16):
                            cmd += ' '
                    if DEBUG:
                        print('|'+cmd+'|')
                    str += cmd
        if DEBUG:
            print('------------------')
        lcd.home()
        lcd.message(str)

    def update(self, command):
        #global currentLcd
        global lcdstart
        #lcd.backlight(currentLcd)
        lcdstart = datetime.now()
        if DEBUG:
            print('do',command)
        if command == 'u':
            self.up()
        elif command == 'd':
            self.down()
        elif command == 'r':
            self.right()
        elif command == 'l':
            self.left()
        elif command == 's':
            self.select()
    def up(self):
        if self.curSelectedItem == 0:
            return
        elif self.curSelectedItem > self.curTopItem:
            self.curSelectedItem -= 1
        else:
            self.curTopItem -= 1
            self.curSelectedItem -= 1
    def down(self):
        if self.curSelectedItem+1 == len(self.curFolder.items):
            return
        elif self.curSelectedItem < self.curTopItem+lcd_rows-1:
            self.curSelectedItem += 1
        else:
            self.curTopItem += 1
            self.curSelectedItem += 1
    def left(self):
        if isinstance(self.curFolder.parent, Folder):
            # find the current in the parent
            itemno = 0
            index = 0
            for item in self.curFolder.parent.items:
                if self.curFolder == item:
                    if DEBUG:
                        print('foundit')
                    index = itemno
                else:
                    itemno += 1
            if index < len(self.curFolder.parent.items):
                self.curFolder = self.curFolder.parent
                self.curTopItem = index
                self.curSelectedItem = index
            else:
                self.curFolder = self.curFolder.parent
                self.curTopItem = 0
                self.curSelectedItem = 0
    def right(self):
        if isinstance(self.curFolder.items[self.curSelectedItem], Folder):
            self.curFolder = self.curFolder.items[self.curSelectedItem]
            self.curTopItem = 0
            self.curSelectedItem = 0
        elif isinstance(self.curFolder.items[self.curSelectedItem], Widget):
            if DEBUG:
                print('eval', self.curFolder.items[self.curSelectedItem].function)
            eval(self.curFolder.items[self.curSelectedItem].function+'()')
        elif isinstance(self.curFolder.items[self.curSelectedItem], CommandToRun):
            self.curFolder.items[self.curSelectedItem].Run()

    def select(self):
        if DEBUG:
            print('check widget')
        if isinstance(self.curFolder.items[self.curSelectedItem], Widget):
            if DEBUG:
                print('eval', self.curFolder.items[self.curSelectedItem].function)
            eval(self.curFolder.items[self.curSelectedItem].function+'()')

# now start things up
uiItems = Folder('root','')

dom = parse(configfile) # parse an XML file by name

top = dom.documentElement

#currentLcd = lcd.OFF
LcdOff()
ProcessNode(top, uiItems)

display = Display(uiItems)
display.display()
lcdstart = datetime.now()

if DEBUG:
    print('setup gpio')



if GPIO.input(channel) == False:
    if DEBUG:
        print ('Push');
global buttonPressed
buttonPressed = 1

if DEBUG:
    print('start while')

while 1:
    if DEBUG:
        print ("In main while loop");
    if (buttonPressed):
        if DEBUG:
            print ("Button Pushed");
       	display.update('Button!')
        display.display()
        sleep(0.25)
'''
# I don't have this many buttons connected
    if (lcd.buttonPressed(lcd.UP)):
        display.update('u')
        display.display()
        sleep(0.25)

    if (lcd.buttonPressed(lcd.DOWN)):
        display.update('d')
        display.display()
        sleep(0.25)

    if (lcd.buttonPressed(lcd.RIGHT)):
        display.update('r')
        display.display()
        sleep(0.25)

    if (lcd.buttonPressed(lcd.SELECT)):
        display.update('s')
        display.display()
        sleep(0.25)

    if AUTO_OFF_LCD:
        lcdtmp = lcdstart + timedelta(seconds=5)
        if (datetime.now() > lcdtmp):
            if DEBUG:
                print('Auto LCD off')
            #lcd.backlight(lcd.OFF)
'''

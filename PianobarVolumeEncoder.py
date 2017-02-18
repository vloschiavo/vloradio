#!/usr/bin/env python

# Use a Rotary Encoder to adjust the volume of Pianobar
# Shamelessly copied from:
# http://blog.dominichenko.com/2015/06/adafruit-rotary-encoder-for-raspberry-pi.html 
# 
# Minor modifications made by V. Loschiavo
# Feb 15, 2017
#
# Uses the internal pull up resistors for GPIO pins on Raspberry Pi
# If you have a digital encoder with a push button, uncomment the commented code below for "channelC"

import time
import datetime
import RPi.GPIO as GPIO
import os
 
from Queue import Queue

# Define the Broadcom GPIO numbering to define which pins you've hooked up your encoder to:
# channel A is one side of the three pins, channel b is the other side.  The middle pin goes to ground.
# channel C is the push button 
channelA = 13
channelB = 5
#channelC = 16
q = Queue()

# Pianobar control FIFO location:  
CTLFILE=(os.getenv("EPHEMERAL")+ "/ctl")

def main():
 GPIO.setmode(GPIO.BCM)
 GPIO.setwarnings(False)
 
 # Define the pins as inputs and use the internal pull-up resistors
 GPIO.setup(channelA, GPIO.IN, pull_up_down=GPIO.PUD_UP)
 GPIO.setup(channelB, GPIO.IN, pull_up_down=GPIO.PUD_UP)
# GPIO.setup(channelC, GPIO.IN, pull_up_down=GPIO.PUD_UP)
 
 # Use interrupts to detect pin changes - this saves us from having to poll the pins in a loop
 # the GPIO.BOTH setting detects both the rising and falling edges 
 GPIO.add_event_detect(channelA, GPIO.BOTH, callback=roll_callback)
 GPIO.add_event_detect(channelB, GPIO.BOTH, callback=roll_callback)
# GPIO.add_event_detect(channelC, GPIO.FALLING, callback=push_callback, bouncetime=300)
 
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

  # Open the FIFO file handle so that we can append control signals to the file for pianobar 
  f = open(os.getenv("CTLFILE"), "a")
 
  # If the knob turned clockwise turn up the volume
  if action > 0:
   f.write( ')))'); 
   
  # If the knob turned counter-clockwise (anti-clockwise) turn down the volume
  elif action < 0:
   f.write( '((('); 
 
  f.close()

 q.put((cur_pos, flags))

''' 
# If you pushed the button (channelC)
def push_callback(channel):
 if GPIO.input(channel) == False:
  print 'Push'
'''

if __name__ == '__main__':
 main()

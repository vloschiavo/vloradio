/* Convert RF signal into bits (humidity/temperature sensor version) 
 * Written by : Ray Wang (Rayshobby LLC)
 * http://rayshobby.net/?p=8998
 * Update: adapted to RPi using WiringPi
*/

// ring buffer size has to be large enough to fit
// data between two successive sync signals

#include <wiringPi.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>

#define RING_BUFFER_SIZE  256

#define SYNC_LENGTH 2200

#define SYNC_HIGH  600
#define SYNC_LOW   600
#define BIT1_HIGH  400
#define BIT1_LOW   220
#define BIT0_HIGH  220
#define BIT0_LOW   400

#define DATAPIN  12  // wiringPi 26 - GPIO 12

unsigned long timings[RING_BUFFER_SIZE];
unsigned int syncIndex1 = 0;  // index of the first sync signal
unsigned int syncIndex2 = 0;  // index of the second sync signal
bool received = false;

// detect if a sync signal is present
bool isSync(unsigned int idx) {
  // check if we've received 4 squarewaves of matching timing
  int i;
  for(i=0;i<8;i+=2) {
    unsigned long t1 = timings[(idx+RING_BUFFER_SIZE-i) % RING_BUFFER_SIZE];
    unsigned long t0 = timings[(idx+RING_BUFFER_SIZE-i-1) % RING_BUFFER_SIZE];    
    if(t0<(SYNC_HIGH-100) || t0>(SYNC_HIGH+100) ||
       t1<(SYNC_LOW-100)  || t1>(SYNC_LOW+100)) {
      return false;
    }
  }
  printf("4 square waves detected\n");
  // check if there is a long sync period prior to the 4 squarewaves
  unsigned long t = timings[(idx+RING_BUFFER_SIZE-i)%RING_BUFFER_SIZE];
  if(t<(SYNC_LENGTH-400) || t>(SYNC_LENGTH+400) || digitalRead(DATAPIN) != HIGH) {
    return false;
  }
  printf("sync detected\n");
  return true;
}

/* Interrupt 1 handler */
void handler() {
  static unsigned long duration = 0;
  static unsigned long lastTime = 0;
  static unsigned int ringIndex = 0;
  static unsigned int syncCount = 0;

  // ignore if we haven't processed the previous received signal
  if (received == true) {
    return;
  }
  // calculating timing since last change
  long time = micros();
  duration = time - lastTime;
  lastTime = time;

  // store data in ring buffer
  ringIndex = (ringIndex + 1) % RING_BUFFER_SIZE;
  timings[ringIndex] = duration;

  // detect sync signal
  if (isSync(ringIndex)) {
    syncCount ++;
    // first time sync is seen, record buffer index
    if (syncCount == 1) {
      syncIndex1 = (ringIndex+1) % RING_BUFFER_SIZE;
    } 
    else if (syncCount == 2) {
      // second time sync is seen, start bit conversion
      syncCount = 0;
      syncIndex2 = (ringIndex+1) % RING_BUFFER_SIZE;
      unsigned int changeCount = (syncIndex2 < syncIndex1) ? (syncIndex2+RING_BUFFER_SIZE - syncIndex1) : (syncIndex2 - syncIndex1);
      // changeCount must be 122 -- 60 bits x 2 + 2 for sync
      if (changeCount != 122){
        received = false;
        syncIndex1 = 0;
        syncIndex2 = 0;
	printf("sync detected, incorrect change count\n");
      } 
      else {
        received = true;
      }
    }

  }
}

int t2b(unsigned int t0, unsigned int t1) {
/*
  if (t0>(BIT1_HIGH-100) && t0<(BIT1_HIGH+100) &&
      t1>(BIT1_LOW-100) && t1<(BIT1_LOW+100)) {
    return 1;
  } else if (t0>(BIT0_HIGH-100) && t0<(BIT0_HIGH+100) &&
             t1>(BIT0_LOW-100) && t1<(BIT0_LOW+100)){
    return 0;
  }
  printf("Ranges for t0: %d - %d  %d - %d\n",BIT1_HIGH-100,BIT1_HIGH+100,BIT0_HIGH-100,BIT0_HIGH+100);
  printf("Ranges for t1: %d - %d  %d - %d\n",BIT1_LOW-100,BIT1_LOW+100,BIT0_LOW-100,BIT0_LOW+100);
  printf("t0 = %d\n t1 = %d\n",t0,t1);
  return -1;  // undefined
*/
	if(t0 > 50 && t0 < 650 && t1 > 50 && t1 < 650){
		if(t0 > t1){
			return 1;
		} else if(t1 > t0){
			return 0;
		}
	}
	printf("t0 = %d t1 = %d\n",t0,t1); 
	return -1;
}

void loop() {
  if (received == true) {
    printf("Loop: received = true");
    // disable interrupt to avoid new data corrupting the buffer
	system("/usr/local/bin/gpio edge 2 none");
    
    // extract humidity value
    unsigned int startIndex, stopIndex;
    unsigned long humidity = 0;
    bool fail = false;
    startIndex = (syncIndex1 + (3*8+1)*2) % RING_BUFFER_SIZE;
    stopIndex =  (syncIndex1 + (3*8+8)*2) % RING_BUFFER_SIZE;
    
    for(int i=startIndex; i!=stopIndex; i=(i+2)%RING_BUFFER_SIZE) {
      int bit = t2b(timings[i], timings[(i+1)%RING_BUFFER_SIZE]);
      humidity = (humidity<<1) + bit;
      if (bit < 0)  fail = true;
    }
    if (fail) {printf("Decoding error.\n");}
    else {
      printf("Humidity: %d\% /  ",humidity);
    }
    
    // extract temperature value
    unsigned long temp = 0;
    fail = false;
    // most significant 4 bits
    startIndex = (syncIndex1 + (4*8+4)*2) % RING_BUFFER_SIZE;
    stopIndex  = (syncIndex1 + (4*8+8)*2) % RING_BUFFER_SIZE;
    for(int i=startIndex; i!=stopIndex; i=(i+2)%RING_BUFFER_SIZE) {
      int bit = t2b(timings[i], timings[(i+1)%RING_BUFFER_SIZE]);
      temp = (temp<<1) + bit;
      if (bit < 0)  fail = true;      
    }
    // least significant 7 bits
    startIndex = (syncIndex1 + (5*8+1)*2) % RING_BUFFER_SIZE;
    stopIndex  = (syncIndex1 + (5*8+8)*2) % RING_BUFFER_SIZE;
    for(int i=startIndex; i!=stopIndex; i=(i+2)%RING_BUFFER_SIZE) {
      int bit = t2b(timings[i], timings[(i+1)%RING_BUFFER_SIZE]);
      temp = (temp<<1) + bit;
      if (bit < 0)  fail = true;
    }
    if (fail) {printf("Decoding error.\n");}
    else {
      printf("Temperature: %d C  %d F\n",(int)((temp-1024)/10+1.9+.5),(int)(((temp-1024)/10+1.9+0.5)*9/5+32));
    }
/*
	printf("raw data:\n");
	for(int i = syncIndex1; i != syncIndex2; i = (i+1)%RING_BUFFER_SIZE){
		printf("%d ",timings[i]);
	}
	printf("\n");
*/    // delay for 1 second to avoid repetitions
    delay(1000);
    received = false;
    syncIndex1 = 0;
    syncIndex2 = 0;

    // re-enable interrupt
    wiringPiISR(DATAPIN,INT_EDGE_BOTH,&handler);
  }
}

int main(int argc, char * args[]){
	printf("Started and Listening:");
	if(wiringPiSetupGpio() == -1){
		printf("no wiring pi detected\n");
		return 0;
	}

	wiringPiISR(DATAPIN,INT_EDGE_BOTH,&handler);
	while(true){
		loop();
	}
	exit(0);
}


#include "Twiddlerino.h"
#include "PID_v1.h"

//Define Variables we'll be connecting to
double target=0;
double pos = 0;
double PWMOut = 0;
long last_time = 0;
long updateInterval = 10; //send position every updateInterval ms

double p = 0.0;
double i = 0;
double d = 0.0;
//PID myPID(&pos, &PWMOut, &target, p, i, d, REVERSE);

//handle impulses
boolean impulseOn = false;
long impulseStart = 0;
long impulseLength = 10; //ms

//PID compute code
double outMax = 255;
double outMin = -255;
double ITerm = 0;
double sampleTime = 1;
double lastPos = 0;
long lastSampleTime = 0;
boolean reverse = true;


void setTunings(double kp, double ki, double kd)
{
  double sampleTimeInSec = (sampleTime/1000.0);
  p = kp;
  i = ki * sampleTimeInSec;
  d = kd / sampleTimeInSec;
  if (reverse)
  {
    p = 0 - p;
    i = 0 - i; 
    d = 0 - d; 
  }
  ITerm = 0;
}

void setup()
{
  Serial.begin(115200);
  TwiddlerinoInit();
  target = 0;
  setTunings(0.0,0.0,0.0);
}
 

void loop()
{
  pos = ReadEncoder();
  long t = millis();
  long dt = t - last_time;
  if (dt >= updateInterval)
  {
    Serial.println((int)pos);
    last_time = t;
  }
  
  //Impulse when the ball is hit
  byte b = 0;
  while(Serial.available() > 0)
  {
    b = Serial.read();
  }
  if (b == 'i')
  {
    impulseOn = true;
    impulseStart = millis();
  }
  //the state for rough surface
  else if (b == 'd') {setTunings(0,0,0.3);}
  //Jumping state, no feedback for precise control
  else if (b=='j'){setTunings(0,0,0.0);}
  //Gravity platform, hard stop
  else if(b=='g')
  {
    target = pos;
    setTunings(16,10,1);
  }
  //Sticky platform, slow movement
  else if (b=='s')
  {
    target = pos;
    setTunings(1.0,0,2.5);
  }
  
   
   //Compute PID code
   unsigned long now = millis();
   unsigned long timeChange = now - lastSampleTime;
   if(timeChange>=sampleTime)
   {
      //Compute all the working error variables
      double error = target - pos;
      ITerm+= (i * error);
      if(ITerm > outMax) ITerm= outMax;
      else if(ITerm < outMin) ITerm= outMin;
      double dInput = (pos - lastPos);
 
      //Compute PID Output
      double output = p * error + ITerm - (d * dInput);
      
      if(output > outMax) output = outMax;
      else if(output < outMin) output = outMin;
      PWMOut = output;
    
      //Remember some variables for next time
      lastPos = pos;
      lastSampleTime = now;
   }
  
  //render a BASIC impulse by setting PWMOut to max
  // in opposite direction of its current value
  if (impulseOn)
  {
    if ((t - impulseStart) >= impulseLength)
    {
      impulseOn = false;
    } else {
      if (PWMOut >= 0)
      {      
        PWMOut = -255;
      } else {
         PWMOut = 255;
      }
    }
  }
  
  //Write to Twiddlerino
  SetPWMOut(PWMOut);
}

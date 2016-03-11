import processing.serial.*;
import ddf.minim.*;

// Updated for Processing 3.0

//sounds
Minim minim;
AudioPlayer toc;

//constants
int WIDTH = 800;
int HEIGHT = 600;


//variables
 //<>//
boolean paused = true;


String serialPortName = "/dev/cu.usbserial-A9007N5P";
//String serialPortName = "COM3";
int SERIAL_WRITE_LENGTH = 32;

platform[] platforms;
runner r1 = new runner();

class platform
{
  float pos = 0;
  float h = 0;
  float w = 0;
  int type = 0;
}

class runner
{
  float pos = 0;
  float w = 20;
  float h = 0;
  int jumpStart = 0;
  boolean jumping = false;
  int jumpTime = 600;
  boolean falling = false; 
  float jumpSpeed = 12;
}

float highScore = 0;
float dropSpeed = -6;
float deathLevel = -200;
float maxH = 200;
int currentPlat = 0;
int twiddlerPosition = 0;
int oldTwidPos = 0;


int platformsPassed = 1;

Serial myPort;
void settings() 
{
  size(WIDTH,HEIGHT);  
}

void createNewPlat()
{
  if (currentPlat == 0)
  {
      platforms[1].w =  random(40.0,120.0);
      platforms[1].pos = platforms[0].pos + random(platforms[0].w + platforms[1].w + 20,platforms[0].w + platforms[1].w + 60);
      platforms[1].h = platforms[0].h + random(-40,40);
      if (platforms[1].h < deathLevel) platforms[1].h =  deathLevel + 1;
      else if (platforms[1].h >= maxH) platforms[1].h = maxH -1;
      
      if (platformsPassed > 5)
      {
        platforms[1].type = (int)random(0.0,4.0);
      }
  }
  else if (currentPlat == 1)
  {
      platforms[0].w = random(40.0,120.0);
      platforms[0].pos = platforms[1].pos + random(platforms[0].w + platforms[1].w + 20,platforms[0].w + platforms[1].w + 60);
      platforms[0].h = platforms[1].h + random(-40,40);
      if (platforms[0].h < deathLevel) platforms[0].h =  deathLevel + 1;
      else if (platforms[0].h >= maxH) platforms[0].h = maxH -1;
      if (platformsPassed > 5)
      {
        platforms[0].type = (int)random(0.0,4.0);
      }
  }
  platformsPassed++;
}

void setup()
{
  frameRate(30);
  myPort = new Serial(this, serialPortName, 115200);
  
  platforms = new platform[2];
  platforms[0] = new platform();
  platforms[1] = new platform();
  
  //for sounds
  minim = new Minim(this);
  toc = minim.loadFile("toc.wav");
  
  randomSeed(millis());
  
  InitializeGame();
}


void draw() {
  background(255);
  fill(0, 0, 0);
  stroke(0,0,255);
  
  UpdateGame();
  DrawGame();
}

/*
  Detailed functions
*/

void InitializeGame()
{
  currentPlat = 0;
  platformsPassed = 1;
  platforms[0].w = 100;
  platforms[0].pos = -50;
  platforms[0].h = 0;
  platforms[0].type = 0;
  platforms[1].type = 0;
  
  r1.pos = 0;
  r1.w = 20;
  r1.h = 0;
  r1.jumpStart = 0;
  r1.jumping = false;
  r1.falling = false; 
  createNewPlat();
}

void UpdateGame()
{
   int t = millis();
   /*
    * UPDATE PLAYER
    */
   ReadTwiddler();
   
   int dp = twiddlerPosition - oldTwidPos;
   if (oldTwidPos == 0)
   {
     oldTwidPos = twiddlerPosition;
     return;
   }
   //We'll see discontinuities when the position rolls over, discard those
   boolean stuck = platforms[currentPlat].type == 2 && (!r1.jumping && !r1.falling);
   if (!(abs(dp) > 1000) && !stuck)
   {
      //runner moves horizontally based on rotation, 5 degrees is one pixel  
      r1.pos = r1.pos + (float) dp/5.0; 
   }
   
   //If users moves off current PLatform create a new one and start falling (usually means death if teh target is not right below.
   if (r1.pos >= platforms[currentPlat].pos + platforms[currentPlat].w)
   {
       currentPlat = (currentPlat + 1)%2;
       createNewPlat();
       if (!r1.jumping && !r1.falling)
       {
         r1.falling = true;
         r1.jumping = true;
         r1.jumpStart = millis(); 
         myPort.write("j");
         
       }
   }
   
   float runnerForce = 0;
   if (r1.falling || r1.jumping)
   {
     runnerForce = dropSpeed;
     if (r1.jumping && ((t - r1.jumpStart) < r1.jumpTime))
     {
       runnerForce = runnerForce + r1.jumpSpeed;
     }
     else if ((t- r1.jumpStart) > r1.jumpTime)
     {
       r1.jumping = false;
     }
   }
   r1.h = r1.h + runnerForce;
   
   if (r1.h <= deathLevel)
   {
     myPort.write("i");
     highScore = max(highScore, r1.pos);
     InitializeGame();
   }
   
   //At this point we've already adjusted currentplat to point to the platform we are above
   for (int i=0; i < 2; i++)
   {
     if ((r1.falling && !r1.jumping) && (r1.pos + r1.w + 3 >= platforms[i].pos) && (r1.pos - 3 <= platforms[i].pos + platforms[i].w) && abs((r1.h - r1.w) - platforms[i].h) < 5)
     {  
        r1.falling = false;
        r1.h = platforms[i].h;
        switch(platforms[i].type)
        {
          case 0:
            //default
            myPort.write("j");
            break;
          case 1:
            //sticky
            myPort.write("s");
            break;
          case 2:
            //gravity
            myPort.write("g");
            break;
          case 3:
            myPort.write("d");
            break;
        }
        //Send input to arduino here
     }
   }
   
   
   
   oldTwidPos = twiddlerPosition;
}

void mousePressed()
{
  paused = !paused;
}

void keyPressed() {
  
  if (key == ' ' && !r1.jumping && !r1.falling)
  {
    r1.falling = true;
    r1.jumping = true;
    r1.jumpStart = millis(); 
    myPort.write("j");
  }
}

void ReadTwiddler()
{
    String inputString = "";
    
    byte input[] = new byte[256];
    while(myPort.available() > 0)
    {
      input = myPort.readBytes();
     }
     if (input != null)
     {
       inputString = new String(input);
       String[] inputStrings = inputString.split("\r\n");
       if (inputStrings.length >= 2)
       {
         try {
           
         twiddlerPosition = Integer.parseInt(inputStrings[inputStrings.length-2]);
         }
       catch(NumberFormatException e)
     {
     }
   finally {}
       }
     }
}

void DrawGame()
{
  background(0); //black bg
  
  fill(255); //white fill
  stroke(255);  //white stroke
  
  textSize(36);
  text("High Score: " + (int) highScore, WIDTH/2 , 50);
  text("Current: " + (int) r1.pos, 50,50);
  
  //runner
  rect(WIDTH/2 - 200, HEIGHT/2 - r1.h, r1.w,r1.w);
  
  
  
  switch(platforms[0].type)
  {
    //Default - d
    case 0:
      fill(0,0,255);
      stroke(0,0,255);
      break;
   //sticky - s
   case 1:
      fill(0,255,0);
      stroke(0,255,0);
      break;
   //gravity - r
   case 2:
      fill(255,0,0);
      stroke(255,0,0);
      break;
   //No Feedback
   case 3:
      fill(255,255,0);
      stroke(255,255,0);
      break;
   
  }
  //platform1;
  rect((WIDTH/2)  - ((r1.pos - platforms[0].pos)) - 200, (HEIGHT/2) + 20 - platforms[0].h ,platforms[0].w,5);
  //platform2
  switch(platforms[1].type)
  {
    //Default - d
    case 0:
      fill(0,0,255);
      stroke(0,0,255);
      break;
   //sticky - s
   case 1:
      fill(0,255,0);
      stroke(0,255,0);
      break;
   //gravity - r
   case 2:
      fill(255,0,0);
      stroke(255,0,0);
      break;
   case 3:
      fill(255,255,0);
      stroke(255,255,0);
      break;
   
  }
  rect((WIDTH/2)  - ((r1.pos - platforms[1].pos)) - 200, (HEIGHT/2) + 20 - platforms[1].h ,platforms[1].w,5);
  
}
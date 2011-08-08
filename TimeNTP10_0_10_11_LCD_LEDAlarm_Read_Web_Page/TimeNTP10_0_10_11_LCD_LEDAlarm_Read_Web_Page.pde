#include <SPI.h>
#include <Time.h> 
#include <Ethernet.h>
#include <Udp.h>
#include <LiquidCrystal.h>

// initialize the library with the numbers of the interface pins
LiquidCrystal lcd(4, 3, A5, A4, A3, A2);

const int NTP_PACKET_SIZE= 48; // NTP time stamp is in the first 48 bytes of the message

int relayPin = 8;
int errorPin = 9;
int displaySwitch = 2;

int numberAlarms = 0;
int alarmArray[50] [5];

boolean summerOffset = 0;
                     
//String ethernetRead;                     

byte packetBuffer[ NTP_PACKET_SIZE]; //buffer to hold incoming and outgoing packets 

byte mac[] = { 0xDE, 0xAD, 0xBE, 0xEF, 0x10, 0xAD };
byte ip[] = { 10,0,10,11 };
byte gateway[] = { 10,0,10,25 };
byte server[] = {10, 0, 0, 5 }; //Belton

byte SNTP_server_IP[] = { 10, 0, 0, 10}; // A10

Client client(server, 80);

time_t prevDisplay = 0; // when the digital clock was displayed
long timeZoneOffset = -3602L; // set this to the offset in seconds to your local time;

void setup() 
{
  lcd.begin(20, 4);
  pinMode(relayPin, OUTPUT);
  pinMode(errorPin, OUTPUT);
  pinMode(displaySwitch, INPUT);
  digitalWrite (errorPin, HIGH);
  digitalWrite (relayPin, HIGH);
  digitalWrite (displaySwitch, LOW);
  Serial.begin(9600);
  Ethernet.begin(mac,ip,gateway);  
  lcd.print("Waiting for sync");
   Udp.begin(8888);
  setSyncProvider(getNtpTime);
  while(timeStatus()== timeNotSet)   
     ; // wait until the time is set by the sync provider
  lcd.clear();
}

void loop()
{  
  digitalWrite (errorPin, HIGH);
  if( now() != prevDisplay) //update the display only if the time has changed
  {
    prevDisplay = now();
    digitalClockDisplay();
    checktime();
  } 

}

void checktime(){
  for(int a=0; a < numberAlarms; a++){
    if( hour() == alarmArray [a] [0])
    {
      if( minute() == alarmArray [a] [1])
      {
        if( second() == alarmArray [a] [2])
        {
         digitalWrite(relayPin, LOW);
         delay((alarmArray [a] [3]) * 1000);
          }
          else
           {
            digitalWrite(relayPin, HIGH);
           }}
      else
      {
        digitalWrite(relayPin, HIGH);
      }}
  else
  {
    digitalWrite(relayPin, HIGH);
  }
  }
}  

void digitalClockDisplay()
{
  // digital clock display of the time
  lcd.setCursor(0,0);
  lcd.print(hour());
  lcdprintDigits(minute());
  lcdprintDigits(second());
  lcd.print(" ");
  lcd.print(day());
  lcd.print(" ");
  lcd.print(month());
  lcd.print(" ");
  lcd.print(year()); 
  lcd.print(" ");
  lcd.print(numberAlarms); 
  

for (int i = 0; i < 3; i++){      //columns to display
  for (int j = 1; j < 4; j++){    //rows to display
    lcd.setCursor((i*7),j);
      for (int k = 0; k < 3; k++){    //hhmmss array
        int m = (i*3) + (j-1);           //alarm array
        if (m <= numberAlarms-1){
          lcd.print(alarmArray[m] [k]);
        }
      }
  }
}

}

void lcdprintDigits(int digits){
  // utility function for digital clock display: prints preceding colon and leading 0
  lcd.print(":");
  if(digits < 10)
    lcd.print('0');
  lcd.print(digits);
}

/*-------- NTP code ----------*/

unsigned long getNtpTime()
{

  sendNTPpacket(SNTP_server_IP);
  digitalWrite (errorPin, LOW);
  readWebPage();
  if ( Udp.available() ) {
    for(int i=0; i < 40; i++)
    delay(5);
    //Serial.print(i);
        Udp.readPacket(packetBuffer,NTP_PACKET_SIZE); // ignore every field except the time
       //the timestamp starts at byte 40 of the received packet and is four bytes,
       // or two words, long. First, esxtract the two words:

    unsigned long highWord = word(packetBuffer[40], packetBuffer[41]);
    unsigned long lowWord = word(packetBuffer[42], packetBuffer[43]);  
    // combine the four bytes (two words) into a long integer
    // this is NTP time (seconds since Jan 1 1900):
    unsigned long secsSince1900 = highWord << 16 | lowWord;
    const unsigned long seventy_years = 2208988800UL + timeZoneOffset ;        
    return secsSince1900 - seventy_years ;     
  }
  return 0; // return 0 if unable to get the time
}

unsigned long sendNTPpacket(byte *address)
{
  // set all bytes in the buffer to 0
  memset(packetBuffer, 0, NTP_PACKET_SIZE); 
  // Initialize values needed to form NTP request
  // (see URL above for details on the packets)
  packetBuffer[0] = 0b11100011;   // LI, Version, Mode
  packetBuffer[1] = 0;     // Stratum, or type of clock
  packetBuffer[2] = 6;     // Polling Interval
  packetBuffer[3] = 0xEC;  // Peer Clock Precision
  // 8 bytes of zero for Root Delay & Root Dispersion
  packetBuffer[12]  = 49; 
  packetBuffer[13]  = 0x4E;
  packetBuffer[14]  = 49;
  packetBuffer[15]  = 52;
  // all NTP fields have been given values, now
  // you can send a packet requesting a timestamp: 		   
  Udp.sendPacket( packetBuffer,NTP_PACKET_SIZE,  address, 123); //NTP requests are to port 123  
}

void readWebPage()
{
 int so = 0;
 int a = 0; 
 int at = 0; 
client.flush();
  if (client.connect()) {
    Serial.println("connected");
    // Make a HTTP request:
    client.println("GET /sounder.txt");
    client.println();
   }
 //find number of alarms from first number on web page
  while (client.available()) {
    int c = client.read();
    if (isDigit(c)) {
      so = (so * 10) + (c-48); //48 is ascii code of 0
    }
    else break;
  }
  if (so >= 1){
    timeZoneOffset = -3601;
  }
  else timeZoneOffset = -1;
  
      
    
  
  summerOffset = so;
  Serial.print (so);
  Serial.print (summerOffset);


  while (client.available()) {
    int c = client.read();
    if (isDigit(c)) {
      a = (a * 10) + (c-48); //48 is ascii code of 0
    }
    else break;
  }

  numberAlarms = int(a);
  Serial.print ("number of alarms "); Serial.println (numberAlarms);
    //fill alarmArray with values from web page
    for ( int count = 0; count < numberAlarms; count++){
      for (int times = 0; times < 5; times++){
        while (client.available()) {
          int c = client.read();
          if (isDigit(c)) {
            at = (at * 10) + (c-48);
          }
          else break;
           }
          alarmArray[count][times] = at;
          Serial.print(count); Serial.print(times); Serial.print(" =");Serial.println(at);
          at = 0;
        }
      }
}

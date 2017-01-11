' Datalogger Test
' 2-21-11 BJH


CON

_clkmode = xtal1 + pll16x
_xinfreq = 5_000_000       '80 MHz


SCL = 4 'I2C display
SDT = 5

sSCL = 26 'RTC
sSDT = 27


Rsense = 6
Lsense = 7
Soap = 16

Red = 20
Blue = 22


{
Dip Switch Settings

1 : ON = Reminder chime ON                              OFF = Reminder chime off
2 : ON = Light Indicator ON                             OFF = Light Indicator 
3 : 
4 : 
5 : ON = Second reminder while waiting for santizier    OFF = No second reminder
6 :
7 :
8 : ON = On boot set clock to contents of TIMESET.TXT   OFF = Normal operation 
}


CON

    buffSize = 100

    Chime = 8
    Light = 9
    SecondReminder = 10




    SetTime = 15


    

    DayStart = 6  'When "daytime" starts
    NightStart = 20             'When "nighttime" starts



VAR long parameter1  'to pass @buff1 to ASM
    long parameter2  'to pass @buff2 to ASM
    long parameter3  'to pass sample rate to ASM
    long parameter4  'to pass #samples to ASM
    long buff1[buffSize]
    long buff2[buffSize]
    long j
    byte Header[44]

    long CogStack[20]
    
VAR

  byte col
  byte line
  byte X
  byte Scrmem[81]
  byte DATABYTE

  byte CRNL[2]
  
  byte filename[12]
  byte audio[7]
  byte SoundPlay
  
  byte timestringStart[8]
  byte timestringEnd[8]
  
  long Rcount
  long Lcount
  byte Direction
  
  byte Time[7]


  byte TimeLoad[25]
  byte Sanitized
  byte addnumber[1]
  
OBJ

    sd0  : "fat16_0"


PUB Startup | g, gg, temp


bytefill(@scrmem,32,80)

Contrast(25)                        
CursorOFF
Bright(8)
CLR

dira[8..15]~                    'DIP switch input bank

dira[20..22]~~                  'LED output


filename[0] := 77               'Month tens
filename[1] := 77               'Month ones
filename[2] := 45               'Dash
filename[3] := 68               'Day tens
filename[4] := 68               'Day ones
filename[5] := 45               'Dash
filename[6] := 89               'Year tens
filename[7] := 89               'Year ones
filename[8] := 46               'Period
filename[9] := 84               'T
filename[10] := 88              'X
filename[11] := 84              'T


audio[3] := 46                  '.
audio[4] := 119                 'w
audio[5] := 97                  'a
audio[6] := 118                 'v


CRNL[0] := 13
CRNL[1] := 10


dbtext(string("SD mount: "),0)
g := sd0.mount(0)
dbtext(string("Success!"),1)

if ina[SetTime] == 0            'Is TimeSet dip switch on?
  SetTheTime


Main




PUB Main | g, checksum, countnum, countthres  


DIRA[Rsense]~ 'Right sensor
DIRA[Lsense]~  'Left sensor

DIRA[Soap]~   'Soap sensor

dbtext(string("Equalizing..."),1)

repeat while ina[Lsense]
repeat while ina[Rsense]

Rcount := 0
Lcount := 0 

dbtext(string("Waiting for Motion"),1)


'Watch for movement and determine direction
repeat

  if ina[Rsense]
    checksum := 0
    repeat 10_000
      checksum += ina[Rsense]
    if checksum > 9500
      MotionDetected(1)

  if ina[Lsense]
    checksum := 0
    repeat 10_000
      checksum += ina[Lsense]
    if checksum > 9500
      MotionDetected(0)

  DisplayTime 



PUB MotionDetected(dir) | g, hours, redblink

MakeDateFilename                'Store date that this event happened
StartTimeString                 'Store time sensor was triggered
Direction := dir


clr

if Direction == 0
  dbtext(string("Left to Right"),1)
else
  dbtext(string("Right to left"),1) 
  

'Determine if it's day or night and set the filename to d or n.

g := Time[2]                 'Hours tens (24 hour format)
g >>= 4
g &= %00000011
g *= 10                         'Multiply to 10's place

hours := Time[2]                 'Hours ones
hours &= %0000_1111

hours += g                      'Add the tens to the ones to get 00-23 hours.

audio[0] := 110                'Night! Set to "n" in ASCII

if hours > DayStart and hours < NightStart     'Daytime? Set to "d" in ASCII
  audio[0] := 100


if ina[Chime] == 0                'Reminder on?
  COGINIT(2,Play(1,1),@CogStack)  'Do stuff to get attention.

dbtext(string("Wait for Soap..."),1) 

g := 0
redblink := 0
Sanitized := 0                'No one is clean anymore! 


repeat while g <> 200_000       'Roughly a 20 second "window of opportunity"

  if Sanitized == 0 and ina[Light] == 0                 'Turn on blinking light?
    redblink += 1
    if redblink == 2_000
      outa[red]~~
    if redblink == 4_000
      outa[red]~
    if redblink == 6_000
      redblink := 0

  g += 1
  
  if ina[Soap] == 0                                     'Did they use the sanitizer?
    dbtext(string("Soap Dispensed!"),1)

    outa[red]~

    if ina[Light] == 0
      outa[blue]~~
    
    if Sanitized == 0
      EndTimeString                                     'Store what time did they actually do it?
      
    Sanitized += 1                                      'Increment total of sanitizations in event.
    
    g := 0                                              'Reset counter so we can log more sanitizations. A period of 20 seconds of no sanitizations ends the event.
    waitcnt(40_000_000 + cnt)

    if ina[Chime] == 0
      sd0.pclose
      cogstop(2)
      COGINIT(2, Play(1, 3), @CogStack)                 'Play "Thank You" sound
      waitcnt(80_000_000 + cnt)

  if g == 100_000
    if ina[SecondReminder] == 0 and ina[Chime] == 0 and Sanitized == 0 'Second reminder DIP switch set? (5)
      COGINIT(2, Play(1, 2), @CogStack)   'Play second reminder.


if Sanitized == 0
  dbtext(string("Soap Not Used..."),1)

Datalogger

waitcnt(320_000_000 + cnt)

WaitForNoMotion




PUB Datalogger | g

'Filename has already been created (at instance of detection) in case waiting for soap passes over midnight.

outa[blue]~
outa[red]~

COGSTOP(2)
g := sd0.pclose                 'Stop any file that migbt be playing


clr
dbtext(string("Logging Data..."),1)

g := sd0.popen(@filename, "a")  'A= append file. Creates a new file if one doesn't exist.  
if g == -1
  dbtext(string("Fail!!"),1)
  repeat


g := sd0.pwrite(@timestringStart, 8)

if Direction := 0
  WriteLine(string(" -Left to Right-"),0)
else
  WriteLine(string(" -Right to Left-"),0)
 
if ina[Chime] == 1
  WriteLine(string(" -no chime- "),0)
if ina[Chime] == 0
  WriteLine(string(" --CHIME--- "),0)

if ina[Light] == 1
  WriteLine(string(" -no light- "),0)
if ina[Light] == 0
  WriteLine(string(" --LIGHT--- "),0)

addnumber.byte[0] := Sanitized + 47
  
if Sanitized 
  WriteLine(string(" SANITIZED AT: "),0)
  g := sd0.pwrite(@timestringEnd, 8)
  if Sanitized > 1
    WriteLine(string(" + "),0)
    WriteLine(@addnumber,0)
    WriteLine(string(" additional sanitizations."),0)
  
else
  WriteLine(string(" no sanitization within 20 seconds."),0)

EndOfLine

g := sd0.pclose                 'Close the file and go back






PUB WaitForNoMotion | counter, target

target := 100_000
counter := 0

dbtext(string("Waiting for Motion Clear..."),1)
 
repeat while counter < target
  
  if ina[Rsense] == 0
    Counter += 1

  if ina[Lsense] == 0
    Counter += 1


clr
dbtext(string("Waiting for Motion"),1)






PUB TextFileTest | g




repeat
 

dbtext(string("File:"),0)

g := sd0.popen(@filename, "a")  'A= append file. Creates a new file if one doesn't exist.  
if g == -1
  dbtext(string("Fail!!"),1)
  repeat
  
dbtext(string("Success!"),1)



dbtext(string("Writing..."),0)
 
 
WriteLine(string("Hello world!"),1)


g := sd0.pclose  

dbtext(string("Done!"),1)








PUB WriteLine(str_addr, crbit) | g, size
 
size := strsize(str_addr)

g := sd0.pwrite(str_addr, size)

if crbit
  EndOfLine



PUB EndOfLine | g

'Can also be used to make a blank line

g := sd0.pwrite(@CRNL, 2)





PUB SetTheTime | g, temp

{Opens TIMESET.TXT file off card and sets the RTC to the time in the file.
Format:
MM-DD-YY
HH-MM-SS
24 hour format
}


g := sd0.popen(string("TIMESET.TXT"), "r")  'A= append file. Creates a new file if one doesn't exist.  
if g == -1
  dbtext(string("Fail!!"),1)
  repeat

g := sd0.pread(@TimeLoad, 25)
g := sd0.pclose

repeat g from 0 to 25                                   'Turn ASCII into numerals
  TimeLoad[g] := TimeLoad[g] - 48


INIT
Start
Write(%11010000)
Write(0) 'Start at address 0


Write(%0) 'Seconds, who gives a damn?

temp := TimeLoad[13] 'Get minutes 10's place
temp <<= 4           'Shift 4
temp += TimeLoad[14] 'Get minutes one's place
Write(temp) 'Minutes

temp := TimeLoad[10] 'Get hours 10's place
temp <<= 4           'Shift 4
temp += TimeLoad[11] + %01000000 'Get hours ones's place and add the 24 hour flag bit
Write(temp) 'Hours (24 hour format)

temp := TimeLoad[10] 'Get day of the week
Write(temp) 'Day of week

temp := TimeLoad[3] 'Get day 10's place
temp <<= 4           'Shift 4
temp += TimeLoad[4] 'Get hours ones's place and add the 24 hour flag bit
Write(temp) 'Day

temp := TimeLoad[0] 'Get months 10's place.
temp <<= 4           'Shift 4
temp += TimeLoad[1] 'Get months ones's place
Write(temp) 'Month

temp := TimeLoad[6] 'Get years 10's place. (nope, it's not Y2K2 compliant!)
temp <<= 4           'Shift 4
temp += TimeLoad[7] 'Get years ones's place
Write(temp) 'Year

Stop

clr
dbtext(string("Time set. Switch DIP8 to OFF and restart"),1)

repeat








PUB play(group, clip) | n,i, SampleRate,Samples

SoundPlay := 1

audio[1] := group + 64
audio[2] := clip + 64

    
  i:=sd0.popen(@audio, "r")
  if (i<>0)
    repeat

  i:=sd0.pread(@Header, 44)
  SampleRate:=Header[27]<<24+Header[26]<<16+Header[25]<<8+Header[24]
  Samples:=Header[43]<<24+Header[42]<<16+Header[41]<<8+Header[40]
  Samples:=Samples>>2
       
  parameter1:=@buff1[0]
  parameter2:=@buff2[0]
  parameter3:=CLKFREQ/SampleRate  '#clocks between samples'1814'for 44100ksps,  5000 'for 16ksps
  parameter4:=Samples
  COGINIT(3,@ASMWAV,@parameter1)
  
  'Keep filling buffers until end of file
  ' note:  using alternating buffers to keep data always at the ready...
  n:=buffSize-1
  j:=buffsize*4   'number of bytes to read
  
  repeat while (j==buffsize*4)  'repeat until end of file
    
    if (buff1[n]==0)
      j:=sd0.pread(@buff1, buffSize*4) 'read data words to input stereo buffer   

    if (buff2[n]==0)
      j:=sd0.pread(@buff2, buffSize*4) 'read data words to input stereo buffer


COGSTOP(3)
sd0.pclose

SoundPlay := 0
  
COGSTOP(2)


 
DAT
  ORG 0
ASMWAV
'load input parameters from hub to cog given address in par
        movd    :par,#pData1             
        mov     xx,par
        mov     y,#4  'input 4 parameters
:par    rdlong  0,xx
        add     :par,dlsb
        add     xx,#4
        djnz    y,#:par

setup
        'setup output pins
        MOV DMaskR,#1
        ROL DMaskR,OPinR
        OR DIRA, DMaskR
        MOV DMaskL,#1
        ROL DMaskL,OPinL
        OR DIRA, DMaskL
        'setup counters
        OR CountModeR,OPinR
        MOV CTRA,CountModeR
        OR CountModeL,OPinL
        MOV CTRB,CountModeL
        'Wait for SPIN to fill table
        MOV WaitCount, CNT
        ADD WaitCount,BigWait
        WAITCNT WaitCount,#0
        'setup loop table
        MOV LoopCount,SizeBuff  
        'ROR LoopCount,#1    'for stereo
        MOV pData,pData1
        MOV nTable,#1
        'setup loop counter
        MOV WaitCount, CNT
        ADD WaitCount,dRate


MainLoop
        SUB nSamples,#1
        CMP nSamples,#0 wz
        IF_Z JMP #Done
        waitcnt WaitCount,dRate

        RDLONG Right,pData
        ADD Right,twos      'Going to cheat a bit with the LSBs here...  Probably shoud fix this!    
        MOV FRQA,Right
        ROL Right,#16       '16 LSBs are left channel...
        MOV FRQB,Right
        WRLONG Zero,pData
        ADD pData,#4

        'loop
        DJNZ LoopCount,#MainLoop
        
        MOV LoopCount,SizeBuff        
        'switch table       ?
        CMP nTable,#1 wz
        IF_Z JMP #SwitchToTable2
SwitchToTable1
        MOV nTable,#1
        MOV pData,pData1
        JMP #MainLoop
SwitchToTable2
        MOV nTable,#2
        MOV pData,pData2
        JMP #MainLoop
        
                
Done
         'now stop
        COGID thisCog
        COGSTOP thisCog          

'Working variables
thisCog long 0
xx       long 0
y       long 0
dlsb    long    1 << 9
BigWait long 100000
twos    long $8000_8000
        
'Loop parameters
nTable  long 0
WaitCount long 0
pData   long 0
LoopCount long 0
SizeBuff long buffsize
'Left    long 0
Right   long 0
Zero    long 0          

'setup parameters
DMaskR  long 0 'right output mask
OPinR   long 17 'right channel output pin #                        '   <---------  Change Right pin# here !!!!!!!!!!!!!!    
DMaskL  long 0 'left output mask 
OPinL   long 18 'left channel output pin #                         '   <---------  Change Left pin# here !!!!!!!!!!!!!!    
CountModeR long %00011000_00000000_00000000_00000000
CountModeL long %00011000_00000000_00000000_00000000


'input parameters
pData1   long 0 'Address of first data table        
pData2   long 0 'Address of second data table
dRate    long 5000  'clocks between samples
nSamples long 2000


{{
                            TERMS OF USE: MIT License

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
}}





{LCD DRIVER CODE BEGIN}
PUB Alert | g                   'Pulses brightness of LCD to get attention

repeat 3

  repeat g from 8 to 1
    Bright(g)
    waitcnt((CLKFREQ / 1000)* 30 + cnt) 

  repeat g from 1 to 8
    Bright(g)
    waitcnt((CLKFREQ / 1000)* 30 + cnt)
 
Bright(8)

PUB CursorON

dbSTART

dbWrite($FE) 
dbWrite($4B)               

dbSTOP

PUB CursorOFF

dbSTART

dbWrite($FE) 
dbWrite($4C)                

dbSTOP


PUB Contrast(temp)

dbSTART

dbWrite($FE) 
dbWrite($52)  
dbWrite(temp)               'Set contrast 1-50 (low to high)

dbSTOP

PUB Bright(temp)

dbSTART

dbWrite($FE) 
dbWrite($53)  
dbWrite(temp)               'Set brightness 1-8 

dbSTOP

PUB POS(curx,cury) | realline   'Position the cursor, using old Atari BASIC language :)

if cury == 1
  realline := 0
if cury == 2
  realline := 64 
if cury == 3
  realline := 20
if cury == 4
  realline := 84


dbSTART
  
dbWrite($FE) 
dbWrite($45) 
dbWrite(realline+ (curx - 1))

dbSTOP 

PUB CLR                         'Clears screen, sets cursor/line to 1/1

dbSTART

dbWrite($FE) 
dbWrite($51)              'Clear screen
col := 1
line := 1

dbSTOP 


PUB CR                          'Perform carriage-return (like there's even a mechanical carriage anymore)
                                'Only call from within other operations, since it does not contain its own START-STOP condition
col := 1
line := line + 1
if line == 5
  line := 1 
POS(col,line)

PUB Writescreen(temp)

Scrmem[x] := temp


PUB Message(str_addr)

POS(1,4)
dbText(string("                    "),0)
POS(1,4)
dbText(str_addr,0)  

PUB dbTEXT(stringptr,crbit) | temp, temp1, g, gg, count                      'Prints text. 0 = no carriage return, 1= carriage return
                                                                             'Includes word-wrap for fun & profit.
dbSTART 
g := 0
count := 0

  repeat strsize(stringptr)
    temp := byte[stringptr + g]
    dbWrite(temp)
    col := col + 1
    g := g + 1

    if temp == 32                                       'Check if next word will fit on current line.
      gg := g
      count := col
       repeat   
         if byte[stringptr + gg] == 32 or byte[stringptr + gg] == 0 
          quit 
         gg := gg + 1
         count := count + 1
      if count > 21                                     'If not, put cursor past limit to initiate carriage return.
        col := 21
  
    if col == 21
      col := 1
      line := line + 1
      dbSTOP
      POS(col,line)
      dbSTART
      if byte[stringptr + g] == 32
        g := g + 1

    
if crbit
  CR



PUB dbDEC(value,crbit) | i

'' Print a decimal number

dbSTART

  if value < 0
    -value
    dbWrite("-")

  i := 1_000_000_000

  repeat 10
    if value => i
      dbWrite(value / i + "0")
      value //= i
      result~~
    elseif result or i == 1
      dbWrite("0")
    i /= 10     

if crbit
  CR

dbSTOP 

PUB dbBIN(value, digits)

'' Print a binary number

dbSTART

  value <<= 32 - digits
  repeat digits
    dbWrite((value <-= 1) & 1 + "0")

CR

dbSTOP 




PUB dbINIT             ' An I2C device may be left in an
                    '  invalid state and may need to be
   outa[SCL] := 1                       '   reinitialized.  Drive SCL high.
   dira[SCL] := 1
   dira[SDT] := 0                       ' Set SDA as input
   repeat 9
      outa[SCL] := 0                    ' Put out up to 9 clock pulses
      outa[SDT] := 1
      if ina[SDT]                      ' Repeat if SDA not driven high
         quit                          '  by the EEPROM

PUB dbSTART                  ' SDA goes HIGH to LOW with SCL HIGH

   outa[SCL]~~                         ' Initially drive SCL HIGH
   dira[SCL]~~
   outa[SDT]~~                         ' Initially drive SDA HIGH
   dira[SDT]~~
   outa[SDT]~                          ' Now drive SDA LOW
   outa[SCL]~                          ' Leave SCL LOW

   dbWrite(254)              'Call address of I2C device, LCD screen 
  
PUB dbSTOP                     ' SDA goes LOW to HIGH with SCL High

   outa[SCL]~~                         ' Drive SCL HIGH
   outa[SDT]~~                         '  then SDA HIGH
   dira[SCL]~                          ' Now let them float
   dira[SDT]~                          ' If pullups present, they'll stay HIGH

PUB dbWRITE(data1) : ackbit

   ackbit := 0 
   data1 <<= 24
   repeat 8                            ' Output data to SDA
      outa[SDT] := (data1 <-= 1) & 1
      outa[SCL]~~                      ' Toggle SCL from LOW to HIGH to LOW
      outa[SCL]~
   dira[SDT]~                          ' Set SDA to input for ACK/NAK
   outa[SCL]~~
   ackbit := ina[SDT]                  ' Sample SDA when SCL is HIGH
   outa[SCL]~
   outa[SDT]~                          ' Leave SDA driven LOW
   dira[SDT]~~


{DEBUG LCD CODE END}




{I2C DRIVER FOR REAL TIME CLOCK BEGIN}
PUB INIT             ' An I2C device may be left in an
                    '  invalid state and may need to be
   outa[sSCL] := 1                       '   reinitialized.  Drive SCL high.
   dira[sSCL] := 1
   dira[sSDT] := 0                       ' Set SDA as input
   repeat 9
      outa[sSCL] := 0                    ' Put out up to 9 clock pulses
      outa[sSDT] := 1
      if ina[sSDT]                      ' Repeat if SDA not driven high
         quit                          '  by the EEPROM

PUB START                  ' SDA goes HIGH to LOW with SCL HIGH

   outa[sSCL]~~                         ' Initially drive SCL HIGH
   dira[sSCL]~~
   outa[sSDT]~~                         ' Initially drive SDA HIGH
   dira[sSDT]~~
   outa[sSDT]~                          ' Now drive SDA LOW
   outa[sSCL]~                          ' Leave SCL LOW

  
PUB STOP                     ' SDA goes LOW to HIGH with SCL High

   outa[sSCL]~~                         ' Drive SCL HIGH
   outa[sSDT]~~                         '  then SDA HIGH
   dira[sSCL]~                          ' Now let them float
   dira[sSDT]~                          ' If pullups present, they'll stay HIGH

PUB WRITE(data1) : ackbit

   ackbit := 0 
   data1 <<= 24
   repeat 8                            ' Output data to SDA
      outa[sSDT] := (data1 <-= 1) & 1
      outa[sSCL]~~                      ' Toggle SCL from LOW to HIGH to LOW
      outa[sSCL]~
   dira[sSDT]~                          ' Set SDA to input for ACK/NAK
   outa[sSCL]~~
   ackbit := ina[sSDT]                  ' Sample SDA when SCL is HIGH
   outa[sSCL]~
   outa[sSDT]~                          ' Leave SDA driven LOW
   dira[sSDT]~~


PUB Read(ackbit): data
'' Read in i2c data, Data byte is output MSB first, SDA data line is
'' valid only while the SCL line is HIGH.  SCL and SDA left in LOW state.

   data := 0
   dira[sSDT]~                          ' Make SDA an input
   repeat 8                            ' Receive data from SDA
      outa[sSCL]~~                      ' Sample SDA when SCL is HIGH
      data := (data << 1) | ina[sSDT]
      outa[sSCL]~
   outa[sSDT] := ackbit                 ' Output ACK/NAK to SDA
   dira[sSDT]~~
   outa[sSCL]~~                         ' Toggle SCL from LOW to HIGH to LOW
   outa[sSCL]~
   outa[sSDT]~                          ' Leave SDA driven LOW



{I2C DRIVER FOR REAL TIME CLOCK END}



PUB MakeDateFilename | temp

LoadTime

Temp := Time[5]                 'Month tens
Temp >>= 4
filename[0] := 48 + temp

Temp := Time[5]                 'Month ones
Temp &= %0000_1111
filename[1] := 48 + temp 

Temp := Time[4]                 'Date tens
Temp >>= 4
filename[3] := 48 + temp 

Temp := Time[4]                 'Date ones
Temp &= %0000_1111
filename[4] := 48 + temp 

Temp := Time[6]                 'Year tens
Temp >>= 4
filename[6] := 48 + temp

Temp := Time[6]                 'Year ones
Temp &= %0000_1111
filename[7] := 48 + temp



PUB StartTimeString | temp

LoadTime

Temp := Time[2]                 'Hours tens (24 hour format)
Temp >>= 4
Temp &= %00000011
timestringStart[0] := 48 + temp

Temp := Time[2]                 'Hours ones
Temp &= %0000_1111
timestringStart[1] := 48 + temp

timestringStart[2] := 58             'Make a colon

Temp := Time[1]                 'Minutes tens
Temp >>= 4
timestringStart[3] := 48 + temp

Temp := Time[1]                 'Minutes ones
Temp &= %0000_1111
timestringStart[4] := 48 + temp

timestringStart[5] := 58             'Make a colon

Temp := Time[0]                 'Minutes tens
Temp >>= 4
timestringStart[6] := 48 + temp

Temp := Time[0]                 'Minutes ones
Temp &= %0000_1111
timestringStart[7] := 48 + temp

timestringStart[8] := 0              'Zero terminate
  

PUB EndTimeString | temp

LoadTime

Temp := Time[2]                 'Hours tens (24 hour format)
Temp >>= 4
Temp &= %00000011
timestringEnd[0] := 48 + temp

Temp := Time[2]                 'Hours ones
Temp &= %0000_1111
timestringEnd[1] := 48 + temp

timestringEnd[2] := 58             'Make a colon

Temp := Time[1]                 'Minutes tens
Temp >>= 4
timestringEnd[3] := 48 + temp

Temp := Time[1]                 'Minutes ones
Temp &= %0000_1111
timestringEnd[4] := 48 + temp

timestringEnd[5] := 58             'Make a colon

Temp := Time[0]                 'Minutes tens
Temp >>= 4
timestringEnd[6] := 48 + temp

Temp := Time[0]                 'Minutes ones
Temp &= %0000_1111
timestringEnd[7] := 48 + temp

timestringEnd[8] := 0              'Zero terminate




PUB DisplayTime | gg, temp

LoadTime

'Convert that crap to a date and time

POS(1,4)

Temp := Time[2]                 'Hours tens (24 hour format)
Temp >>= 4
Temp &= %00000011
dbdec(temp, 0)

Temp := Time[2]                 'Hours ones
Temp &= %0000_1111
dbdec(temp, 0)

dbtext(string(":"), 0)

Temp := Time[1]                 'Minutes tens
Temp >>= 4
dbdec(temp, 0)

Temp := Time[1]                 'Minutes ones
Temp &= %0000_1111
dbdec(temp, 0)

dbtext(string(":"), 0) 

Temp := Time[0]                 'Minutes tens
Temp >>= 4
dbdec(temp, 0)

Temp := Time[0]                 'Minutes ones
Temp &= %0000_1111
dbdec(temp, 0)


dbtext(string("    "), 0)


Temp := Time[5]                 'Month tens
Temp >>= 4
dbdec(temp, 0)

Temp := Time[5]                 'Month ones
Temp &= %0000_1111
dbdec(temp, 0)

dbtext(string("-"), 0)

Temp := Time[4]                 'Date tens
Temp >>= 4
dbdec(temp, 0)

Temp := Time[4]                 'Date ones
Temp &= %0000_1111
dbdec(temp, 0)

dbtext(string("-"), 0)

Temp := Time[6]                 'Year tens
Temp >>= 4
dbdec(temp, 0)

Temp := Time[6]                 'Year ones
Temp &= %0000_1111
dbdec(temp, 1)





PUB LoadTime | gg

INIT
Start
Write(%11010000)
Write(0)
Stop

Start
Write(%11010001)
repeat gg from 0 to 6
  Time[gg] := Read(0)
Stop


   
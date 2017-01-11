CON

  _CLKMODE = XTAL1 + PLL16X
  _XINFREQ = 5_000_000


JClock = 24
JReset = 25

sSCL = 28 'RTC
sSDT = 29

SetBlinker = 1_000
Bright = 700_000

Latch = 0
Clock = 1
DataL = 2

TimeButton = 7
PushButton = 5

VAR

long Smem[7]                    'Screen memory, one long per row, times 7 rows
long Sbuffer[7]                 'Buffer to build image before copy
long NumTemp[7]                 'Buffer for shifting numeric characters

long parameter1


  
byte Time[7]
byte TimeChange[7]              'Temp variable we change when setting

long LEDBuild
long LEDOut

byte DayOfWeek
byte DayOfWeekOut

byte colontime

long Blinker

byte LastDial

byte testnum


long CogStackP[10]

PUB Main | gg, check

dira[0..2]~~
dira[3..7]~
dira[JClock]~~
dira[JReset]~~

LastDial := ina[4..3]

'SetTheTime(3, 21, 3, 9, 20, 11, 1) 'hour, minute, day of week, day of month, month, year, 0 = AM, 1 = PM

Blinker := cnt                  'Set delay reference


coginit(7, ShowDisplay, @CogStackP)

repeat
  colontime := 0 
  DisplayTime(1)
  repeat 20
    waitcnt(Blinker += 4_000_000)
    CheckButtons
  
  colontime := 1 
  DisplayTime(0)
  repeat 20
    waitcnt(Blinker += 4_000_000)
    CheckButtons

    

PUB CheckButtons


if ina[TimeButton] == 0                  'Time button pushed?

  waitcnt(5_000_000 + cnt) 
  repeat while ina[TimeButton] == 0
  waitcnt(5_000_000 + cnt)
  SetTime

if ina[6] == 0                  'Alarm button pushed?

  'SetAlarm


PUB SetTime | check, temp, hours0, minutes0, dayofweek0, position, timerblink, ampm0

LoadTime

DayofWeek0 :=  Time[3]       'Get day of week     

hours0 := Time[2]                 'Hours tens
hours0 >>= 4
hours0 &= %00000001

Temp := Time[2]                  'Hours ones
Temp &= %0000_1111
hours0 := (hours0 * 10) + Temp

minutes0 := Time[1]
minutes0 >>= 4

Temp := Time[1] & %00001111
minutes0 := (minutes0 * 10) + Temp

Position := 0                   'Start with hours

Temp := Time[2]                 'Check for AM or PM

if (Temp & %00100000)
  ampm0 := 1
else
  ampm0 := 0  


repeat while ina[TimeButton] == 1

  TimerBlink += 1
  if TimerBlink > SetBlinker
    TimerBlink := 0

  Clear
  
  if Position <> 0
    LoadDouble(0, hours0)
    
  if Position == 0
    if TimerBlink < (SetBlinker / 2)
      LoadDouble(0, hours0)     

  if Position <> 1
    LoadDouble(1, minutes0)
    
  if Position == 1
    if TimerBlink < (SetBlinker / 2)
      LoadDouble(1, minutes0) 

  if Position <> 2
    DayofWeek := 1 << dayofweek0                       'Turn day of week numeral into a display 
    
  if Position == 2
    if TimerBlink < (SetBlinker / 2)
      DayofWeek := 1 << dayofweek0                       'Turn day of week numeral into a display     
  
  
  if ampm0 == 1
    LEDBuild += %00000000_00000001_00000000_00000000 'PM light
  else
    LEDBuild += %00000001_00000000_00000000_00000000 'AM light

  

  LoadBuffer

  Check := Dial

  if Check == 1 'Dial down?
    if Position == 0
      hours0 -= 1
      if hours0 == 11           'Did we go down past 12?
        ampm0 := !ampm0 & %00000001           'Invert AMPM
        
      if hours0 < 1
        hours0 := 12
                
    if Position == 1
      minutes0 -= 1
      if minutes0 < 0
        minutes0  := 59

    if Position == 2
      DayOfWeek0 -= 1
      if DayOfWeek0 == 0
        DayOfWeek0 := 7


  if Check == 2 'Dial up?
    if Position == 0
      hours0 += 1
      if hours0 == 12           'Did we go up past 11?
        ampm0 := !ampm0 & %00000001           'Invert AMPM
        

      if hours0 == 13
        hours0 := 1
        
    if Position == 1
      minutes0 += 1
      if minutes0 > 59
        minutes0 := 00

    if Position == 2
      DayOfWeek0 += 1
      if DayOfWeek0 == 8
        DayOfWeek0 := 1

        

  if ina[pushbutton] == 0
    waitcnt(10_000_000 + cnt)
    repeat while ina[pushbutton] == 0
    position += 1
    if position > 2
      position := 0
    waitcnt(10_000_000 + cnt)


Clear
LoadBuffer
    
waitcnt(5_000_000 + cnt)
repeat while ina[TimeButton] == 0
waitcnt(5_000_000 + cnt) 


SetTheTime(hours0, minutes0, dayofweek0, 9, 21, 11, ampm0)

Blinker := cnt                  'Set delay reference  



PUB LoadDouble(position, number0) | pos0, pos1, digit0, digit1

if position == 0
  pos0 := 0
  pos1 := 1
  if number0 > 9                                          '2 digit number?
    LoadNumber(number0 / 10, pos0)
    LoadNumber(number0 - (number0 / 10 * 10), pos1)
  else
    LoadNumber(number0, pos1)
  
if position == 1
  pos0 := 2
  pos1 := 3
  LoadNumber(number0 / 10, pos0)
  LoadNumber(number0 - (number0 / 10 * 10), pos1)







PUB Dial | g, newdial, output

NewDial := ina[4..3]

if (LastDial <> NewDial)        'Did it change?
 
  'LoadNumber(NewDial, 2)  

  repeat g from 1 to 4
  
  if (NewDial == 0)     'A match?
    
    if (LastDial == 1)
      output := 2
    if (LastDial == 2)
      output := 1

  if (NewDial == 2)     'A match?
    
    if (LastDial == 0)
      output := 2
    if (LastDial == 3)
      output := 1

  if (NewDial == 3)     'A match?
    
    if (LastDial == 2)
      output := 2
    if (LastDial == 1)
      output := 1

  if (NewDial == 1)     'A match?
    
    if (LastDial == 3)
      output := 2
    if (LastDial == 0)
      output := 1

  LastDial := NewDial

  return output

else
  return 0



PUB LoadNumber(num, position) | g, temp

temp := number[num]             'Load number

temp <<= ((3 - position) * 8)

LEDBuild |= temp



PUB Clear

LEDBuild := 0
DayOfWeek := 0


PUB LoadBuffer

LEDOut := LEDBuild
DayOfWeekOut := DayOfWeek


PUB DisplayTime(rtc) | gg, temp

if RTC
  LoadTime

Clear
'Convert that crap to a date and time

Temp := Time[2]                 'Hours tens
Temp >>= 4
Temp &= %00000001
if Temp > 0
  LoadNumber(temp, 0)

Temp := Time[2]                 'Hours ones
Temp &= %0000_1111
LoadNumber(temp, 1)

LoadNumber(10, 10) 'Colon  

Temp := Time[1]                 'Minutes tens
Temp >>= 4
LoadNumber(temp, 2)  

Temp := Time[1]                 'Minutes ones
Temp &= %0000_1111
LoadNumber(temp, 3)

DayofWeek := 1 << Time[3]       'Get day of week

if (ColonTime)
  LEDBuild |= %00000000_00000000_00000001_00000000

Temp := Time[2]

if (Temp & %00100000)
  LEDBuild += %00000000_00000001_00000000_00000000 'PM light
else
  LEDBuild += %00000001_00000000_00000000_00000000 'PM light

LoadBuffer



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



PUB SetTheTime(hours, minutes, dayweek, month, day, year, ampm) | g, temp


INIT
Start
Write(%11010000)
Write(0) 'Start at address 0


Write(%0) 'Seconds, who gives a damn?

temp := minutes / 10 'Get minutes 10's place
temp <<= 4           'Shift 4
temp |= minutes - (minutes / 10 * 10) 'Get minutes one's place
Write(temp) 'Minutes


temp := hours / 10 'Get hours 10's place
temp <<= 4           'Shift 4
temp |= hours - (hours / 10 * 10) 'Get hours ones's place

temp |= %01000000               'Set 12 hour mode

temp |= ampm << 5               'Add the am (0) or pm (1) bit 

Write(temp) 'Hours (12 hour format)


temp := dayweek 'Get day of the week
Write(temp) 'Day of week

temp := day / 10 'Get day 10's place
temp <<= 4           'Shift 4
temp += day - (day / 10 * 10) 'Get day 1's place 
Write(temp) 'Day

temp := month / 10 'Get months 10's place.
temp <<= 4           'Shift 4
temp += month - (month / 10 * 10) 'Get months ones's place
Write(temp) 'Month

temp := year / 10 'Get years 10's place. (nope, it's not Y2K2 compliant!)
temp <<= 4           'Shift 4
temp += year - (year / 10 * 10) 'Get years ones's place
Write(temp) 'Year

Write(%00010011) 'Control register

Stop


PUB ShowDisplay | temp0, DisplayRate

DisplayRate := cnt

dira[0..2]~~  

repeat
 
  temp0 := DayOfWeekOut  
 
  repeat 8                        
   
    OUTA[DataL] := temp0                                     'Set next LSB bit for Light0 OUT
    
    OUTA[Clock]~~                                             'CLK input and output shift registers
    OUTA[Clock]~                                              'Sends OUT light data, brings IN sense data, which we now check
   
    temp0 >>= 1                                           'Shift light bits RIGHT to put next one in LSB
    
  temp0 := !LEDOut

   
  repeat 32                       
   
    OUTA[DataL] := temp0                                     'Set next LSB bit for Light0 OUT
    
    OUTA[Clock]~~                                             'CLK input and output shift registers
    OUTA[Clock]~                                              'Sends OUT light data, brings IN sense data, which we now check
   
    temp0 >>= 1                                           'Shift light bits RIGHT to put next one in LSB
    
  OUTA[Latch]~~
  OUTA[Latch]~                                                'Set latches to output light data (also re-latches input data but who cares?)
   
  waitcnt(10_000_000 + cnt)




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

DAT

number
        byte %11101110 'Zero
        byte %00101000 'One
        byte %01110110 'Two
        byte %01111100 'Three
        byte %10111000 'Four
        byte %11011100 'Five
        byte %11011110 'Six
        byte %01101000 'Seven
        byte %11111110 'Eight 
        byte %11111100 'Nine


colon

        long %00000001_00000001_00000001_00000001


rotary

        byte 1
        byte 0
        byte 2
        byte 3
        byte 1
        byte 0


                              
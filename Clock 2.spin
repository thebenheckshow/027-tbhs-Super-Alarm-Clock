CON

  _CLKMODE = XTAL1 + PLL16X
  _XINFREQ = 5_000_000


JClock = 24
JReset = 25

sSCL = 28 'RTC
sSDT = 29


Latch = 0
Clock = 1
DataL = 2

VAR

long Smem[7]                    'Screen memory, one long per row, times 7 rows
long Sbuffer[7]                 'Buffer to build image before copy
long NumTemp[7]                 'Buffer for shifting numeric characters

long parameter1

long Blinker

  
byte Time[7]
long LEDtime
byte DayOfWeek
byte colontime

byte LastDial  


PUB Main | g

dira[0..2]~~
dira[3..7]~
dira[JClock]~~
dira[JReset]~~

Blinker := cnt


'SetTheTime(8, 23, 3, 9, 20, 11, 1) 'hour, minute, day of week, day of month, month, year, 0 = AM, 1 = PM

repeat
  colontime := 0 
  DisplayTime
  waitcnt(Blinker += 80_000_000)
  
  colontime := 1 
  DisplayTime
  waitcnt(Blinker += 80_000_000)



PUB Dial | g, newdial, output

NewDial := ina[4..3]

if (LastDial <> NewDial)        'Did it change?

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

LEDtime |= temp



PUB Clear

LEDtime := 0
DayOfWeek := 0


PUB DisplayTime | gg, temp

LoadTime

Clear
'Convert that crap to a date and time

Temp := Time[2]                 'Hours tens
Temp >>= 4
Temp &= %00000001
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
  LEDtime |= %00000000_00000000_00000001_00000000

Temp := Time[2]

if (Temp & %00100000)
  LEDtime += %00000000_00000001_00000000_00000000 'PM light
else
  LEDtime += %00000001_00000000_00000000_00000000 'PM light

PollIO



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


PUB PollIO | temp0
      


OUTA[Latch]~                                                'Set latch...
OUTA[Clock]~                                                '... and clock to LOW to get started.
OUTA[Latch]~~                                               'Set latches HIGH to start. No change for the lights (registers should still be same as last cycle), brings up first bit of Sense
OUTA[Latch]~                                                'Reset latch for next time


repeat 3
  temp0 := number[8]
   
  repeat 8                        
   
    OUTA[DataL] := temp0                                     'Set next LSB bit for Light0 OUT
    
    OUTA[Clock]~~                                             'CLK input and output shift registers
    OUTA[Clock]~                                              'Sends OUT light data, brings IN sense data, which we now check
   
    temp0 >>= 1                                           'Shift light bits RIGHT to put next one in LSB
   


temp0 := DayOfWeek  

repeat 8                        

  OUTA[DataL] := temp0                                     'Set next LSB bit for Light0 OUT
  
  OUTA[Clock]~~                                             'CLK input and output shift registers
  OUTA[Clock]~                                              'Sends OUT light data, brings IN sense data, which we now check

  temp0 >>= 1                                           'Shift light bits RIGHT to put next one in LSB
  
temp0 := !LEDtime

repeat 32                       

  OUTA[DataL] := temp0                                     'Set next LSB bit for Light0 OUT
  
  OUTA[Clock]~~                                             'CLK input and output shift registers
  OUTA[Clock]~                                              'Sends OUT light data, brings IN sense data, which we now check

  temp0 >>= 1                                           'Shift light bits RIGHT to put next one in LSB
  
OUTA[Latch]~~
OUTA[Latch]~                                                'Set latches to output light data (also re-latches input data but who cares?)



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

        
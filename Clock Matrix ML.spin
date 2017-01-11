CON

  _CLKMODE = XTAL1 + PLL16X
  _XINFREQ = 5_000_000


JClock = 24
JReset = 25

sSCL = 28 'RTC
sSDT = 29


VAR

long Smem[7]                    'Screen memory, one long per row, times 7 rows
long Sbuffer[7]                 'Buffer to build image before copy
long NumTemp[7]                 'Buffer for shifting numeric characters

long parameter1


  
byte Time[7]


PUB Main | g

dira[0..23]~~                   'Set column to outputs
dira[JClock]~~
dira[JReset]~~

parameter1 := @Smem[0]
COGINIT(4, @Setup, @parameter1)

Clear
LoadNumber(1, 0)
LoadNumber(2, 6)
LoadNumber(10, 10) 'Colon
LoadNumber(5, 14)  
LoadNumber(9, 20)

LoadFrame


'SetTheTime(10, 01, 5, 9, 15, 11, 0) 'hour, minute, day of week, day of month, month, year

repeat

  DisplayTime
  waitcnt(40_000_000 + cnt)



PUB LoadNumber(num, position) | g

longmove(@NumTemp[0], @numerals[num * 28], 7)   

repeat g from 0 to 6

  NumTemp[g] <<= position
  Sbuffer[g] |= NumTemp[g]


PUB LoadFrame

longmove(@Smem[0], @Sbuffer[0], 7)

PUB Clear

longfill(@Sbuffer[0], 0, 7)


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
LoadNumber(temp, 6)

LoadNumber(10, 10) 'Colon  

Temp := Time[1]                 'Minutes tens
Temp >>= 4
LoadNumber(temp, 14) 

Temp := Time[1]                 'Minutes ones
Temp &= %0000_1111
LoadNumber(temp, 20)



LoadFrame

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



PUB SetTheTime(hours, minutes, dayofweek, month, day, year, ampm) | g, temp


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


temp := dayofweek 'Get day of the week
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

Stop




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

numerals

        long %01110 'Zero
        long %11011        
        long %11011
        long %11011
        long %11011
        long %11011
        long %01110

        long %01100 'One
        long %01110        
        long %01100
        long %01100
        long %01100
        long %01100
        long %11110

        long %11111 'Two
        long %11011        
        long %11000
        long %11111
        long %00011
        long %00011
        long %11111        

        long %11111 'Three
        long %11111        
        long %11000
        long %11110
        long %11000
        long %11111
        long %11111   

        long %11011 'Four
        long %11011        
        long %11011
        long %11111
        long %11000
        long %11000
        long %11000 

        long %11111 'Five
        long %00011        
        long %00011
        long %11111
        long %11000
        long %11000
        long %11111 

        long %11111 'Six
        long %00011        
        long %00011
        long %11111
        long %11011
        long %11011
        long %11111 

        long %11111 'Seven
        long %11111        
        long %11000
        long %11000
        long %11000
        long %11000
        long %11000 

        long %01110 'Eight
        long %11011        
        long %11011
        long %01110
        long %11011
        long %11011
        long %01110

        long %11111 'Nine
        long %11011        
        long %11011
        long %11111
        long %11000
        long %11000
        long %11000

        long %00000 'Colon
        long %00100        
        long %00100
        long %00000
        long %00100
        long %00100
        long %00000
                        

DAT

ORG 0

Setup

        mov dira, OutputMask

        mov OutputMask, par     'Its work done, OutputMask is now used to set the parameter register

        mov WaitCount, CNT
        add WaitCount,Rate

Frame
        rdlong MemPos, OutputMask 'Get the start of memory address 

        rdlong TempX, MemPos
        add TempX, ResetMask     'Add clock bit
        mov outa, TempX          'Put on the output
        'sub Temp, ResetMask     'Remove the bit
        'mov outa, Temp          'Reassert to output
 
        waitcnt WaitCount,Rate  'No matter what, wait correct number of cycles 

        add MemPos, #4          'Move memory pointer
        mov RowCount, #1

Row
        rdlong TempX, MemPos     'Read contents of screen memory into temp variable         
        add TempX, ClockMask     'Add clock bit
        mov outa, TempX          'Put on the output
        sub TempX, ClockMask     'Remove the bit
        mov outa, TempX          'Reassert to output

        waitcnt WaitCount,Rate  'No matter what, wait correct number of cycles 

        add MemPos, #4          'Move memory pointer
        add RowCount, #1

        cmp RowCount, #8 wz     'Did we do all 7 rows yet?
        if_z jmp #Frame         'If so, start over
        jmp #Row                'Else, do next row


TempX          long 0
MemPos        long 0
OutputMask    long %00000111_11111111_11111111_11111111
RowCount      long 0

ClockMask     long %00000010_00000000_00000000_00000000
ResetMask     long %00000100_00000000_00000000_00000000

Waitcount     long 0
Rate          long 162_000


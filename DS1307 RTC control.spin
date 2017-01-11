' Datalogger Test
' 2-21-11 BJH


CON

_clkmode = xtal1 + pll16x
_xinfreq = 5_000_000       '80 MHz


SCL = 28 'I2C display
SDT = 29

sSCL = 28 'RTC
sSDT = 29



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

  
  byte Time[7]


PUB Startup | g, gg, temp


bytefill(@scrmem,32,80)

Contrast(25)                        
CursorOFF
Bright(8)
CLR


'SetTheTime(10, 01, 5, 9, 15, 11, 0) 'hour, minute, day of week, day of month, month, year

repeat

  DisplayTime
  waitcnt(40_000_000 + cnt)





PUB DisplayTime | gg, temp

LoadTime

'Convert that crap to a date and time

POS(1,4)

Temp := Time[2]                 'Hours tens (24 hour format)
Temp >>= 4
Temp &= %00000001
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

Temp := Time[0]                 'Seconds tens
Temp >>= 4
dbdec(temp, 0)

Temp := Time[0]                 'Seconds ones
Temp &= %0000_1111
dbdec(temp, 0)

Temp := Time[2]
if Temp & %00100000
  dbtext(string(" PM "), 0)
else
  dbtext(string(" AM "), 0) 

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

  
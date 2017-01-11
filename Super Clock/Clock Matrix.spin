CON

  _CLKMODE = XTAL1 + PLL16X
  _XINFREQ = 5_000_000


JClock = 24
JReset = 25

VAR

long Smem[7]                    'Screen memory, one long per row, times 7 rows


PUB Main

dira[0..23]~~                   'Set column to outputs
dira[JClock]~~
dira[JReset]~~

outa[0..23] := %11111111_11111111_11111111

repeat

  outa[JReset]~~                'Reset counter to Q0
  outa[JReset]~

  repeat 7
    'waitcnt(200_000 + cnt)   
    outa[JClock]~~
    outa[JClock]~









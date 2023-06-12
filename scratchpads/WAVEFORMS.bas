' from: https://thewolfsound.com/sine-saw-square-triangle-pulse-basic-waveforms-in-synthesis/

' sine: s(t)=sin(2πft)
' t = time in seconds f = frequency hZ 

' square: s(t)=sgn(sin(2πft))
' t = time in seconds f = frequency hZ 

' triangle: (t)=4 * ABS(​f*t−_ROUND(f*t+1/2)​−1
' t = time in seconds f = frequency hZ 

' saw: s(t)=2(t%f1​)f−1
' 2 * (t MOD FREQ) * FREQ - 1

CONST TWO_PI=_PI(2)
CONST FREQ=900
CONST SECS=3.0

' SINE
t = 0
tmp$ = "Sample = ##.#####   Time = ##.#####"
LOCATE 1, 60: PRINT "Rate:"; _SNDRATE
DO
' queue some sound
  DO WHILE _SNDRAWLEN < 0.1             ' you may wish to adjust this    
    sample = SIN(TWO_PI * FREQ * t)     ' sine wave SIN(2π*f*t)   
    sample = sample * EXP(-t * SECS)    ' fade out eliminates clicks after sound
    _SNDRAW sample
    t = t + 1 / _SNDRATE                ' sound card sample frequency determines time
  LOOP

  'do other stuff, but it may interrupt sound
  LOCATE 1, 1: PRINT USING tmp$; sample; t
LOOP WHILE t < SECS                      ' play for SECS seconds

DO WHILE _SNDRAWLEN > 0                  ' Finish any left over queued sound!
LOOP



' SQUARE
t = 0
tmp$ = "Sample = ##.#####   Time = ##.#####"
LOCATE 1, 60: PRINT "Rate:"; _SNDRATE
DO
' queue some sound
  DO WHILE _SNDRAWLEN < 0.1              ' you may wish to adjust this    
    sample = SGN(SIN(TWO_PI * FREQ * t)) ' square wave SGN(SIN(2π*f*t))
    sample = sample * EXP(-t * SECS)     ' fade out eliminates clicks after sound
    _SNDRAW sample
    t = t + 1 / _SNDRATE                 ' sound card sample frequency determines time
  LOOP

  ' do other stuff, but it may interrupt sound
  LOCATE 1, 1: PRINT USING tmp$; sample; t
LOOP WHILE t < SECS                      ' play for SECS seconds

DO WHILE _SNDRAWLEN > 0                  ' Finish any left over queued sound!
LOOP



' TRIANGLE
' 4 * ABS(​f*t−_ROUND(f*t+1/2) ​− 1
t = 0
tmp$ = "Sample = ##.#####   Time = ##.#####"
LOCATE 1, 60: PRINT "Rate:"; _SNDRATE
DO
' queue some sound
  DO WHILE _SNDRAWLEN < 0.1             ' you may wish to adjust this    
    sample = 4 * ABS(FREQ*t-_ROUND(FREQ*t+1/2))-1 ' triangle wave 4 * ABS(​f*t−_ROUND(f*t+1/2) ​− 1
    sample = sample * EXP(-t * SECS)    ' fade out eliminates clicks after sound
    _SNDRAW sample
    t = t + 1 / _SNDRATE                ' sound card sample frequency determines time
  LOOP

  'do other stuff, but it may interrupt sound
  LOCATE 1, 1: PRINT USING tmp$; sample; t
LOOP WHILE t < SECS                      ' play for SECS seconds

DO WHILE _SNDRAWLEN > 0                  ' Finish any left over queued sound!
LOOP



' SAW
' FREQ * (t MOD 1/FREQ) * FREQ - 1
t = 0
tmp$ = "Sample = ##.#####   Time = ##.#####"
LOCATE 1, 60: PRINT "Rate:"; _SNDRATE
DO
' queue some sound
  DO WHILE _SNDRAWLEN < 0.1             ' you may wish to adjust this    
    sample = 2 * (t MOD FREQ) * FREQ - 1' saw wave FREQ * (t MOD 1/FREQ) * FREQ - 1
    sample = sample * EXP(-t * SECS)    ' fade out eliminates clicks after sound
    _SNDRAW sample
    t = t + 1 / _SNDRATE                ' sound card sample frequency determines time
  LOOP

  'do other stuff, but it may interrupt sound
  LOCATE 1, 1: PRINT USING tmp$; sample; t
LOOP WHILE t < SECS                      ' play for SECS seconds

DO WHILE _SNDRAWLEN > 0                  ' Finish any left over queued sound!
LOOP



END
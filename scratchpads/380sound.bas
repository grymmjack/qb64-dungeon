DIM AS STRING Q, P : Q$ = CHR$(34) : P$ = ""

PRINT "==============================="
PRINT "QB64 PHOENIX EDITION SOUND DEMO"
PRINT "==============================="

MONO:
PRINT
PRINT "--- WAVEFORMS DEMO MONOPHONIC (@n) ---"
P$ = "V25 O3 @1 G D C F" : PRINT "  SQUARE WAVE: PLAY " + Q$ + P$ + Q$ : PLAY P$ 
P$ = "V25 O3 @2 G D C F" : PRINT "     SAW WAVE: PLAY " + Q$ + P$ + Q$ : PLAY P$
P$ = "V25 O3 @3 G D C F" : PRINT "TRIANGLE WAVE: PLAY " + Q$ + P$ + Q$ : PLAY P$
P$ = "V25 O3 @4 G D C F" : PRINT "    SINE WAVE: PLAY " + Q$ + P$ + Q$ : PLAY P$
P$ = "V25 O3 @5 G D C F" : PRINT "   NOISE WAVE: PLAY " + Q$ + P$ + Q$ : PLAY P$

POLY:
PRINT
PRINT "--- WAVEFORMS DEMO POLYPHONIC (@n) ---"
P$ = "V25 O3 @1 G,D,C,F" : PRINT "  SQUARE WAVE: PLAY " + Q$ + P$ + Q$ : PLAY P$
P$ = "V25 O3 @2 G,D,C,F" : PRINT "     SAW WAVE: PLAY " + Q$ + P$ + Q$ : PLAY P$
P$ = "V25 O3 @3 G,D,C,F" : PRINT "TRIANGLE WAVE: PLAY " + Q$ + P$ + Q$ : PLAY P$
P$ = "V25 O3 @4 G,D,C,F" : PRINT "    SINE WAVE: PLAY " + Q$ + P$ + Q$ : PLAY P$
P$ = "V25 O3 @5 G,D,C,F" : PRINT "   NOISE WAVE: PLAY " + Q$ + P$ + Q$ : PLAY P$

MULTI:
PRINT
PRINT "--- WAVEFORMS DEMO MULTI-WAVE (@n) ---"
P$ = "V25 O0@1G,O1@2G"       : PRINT "        SQUARE + SAW WAVES: PLAY " + Q$ + P$ + Q$ : PLAY P$
P$ = "V25 O0@2G,O3@2G"       : PRINT "           SAW + SAW WAVES: PLAY " + Q$ + P$ + Q$ : PLAY P$
P$ = "V25 O0@3<<G,O1@1<<G"   : PRINT "   TRIANGLE + SQUARE WAVES: PLAY " + Q$ + P$ + Q$ : PLAY P$
P$ = "V25 O1@1<G,O1@2>G,@5G" : PRINT "SQUARE + SAW + NOISE WAVES: PLAY " + Q$ + P$ + Q$ : PLAY P$

RAMPS:
PRINT
PRINT "--- WAVEFORM VOLUME RAMP (ATTACK) DEMO (@Q) ---"
P$ = "V50 T60 O2 Q100 @2 G" : PRINT "   60BPM 100MS RAMP FADE IN SAW: PLAY " + Q$ + P$ + Q$ : PLAY P$
P$ = "V50 T60 O2 Q10 @2 G"  : PRINT "    60BPM 10MS RAMP FADE IN SAW: PLAY " + Q$ + P$ + Q$ : PLAY P$
P$ = "V50 T60 O2 Q0 @2 G"   : PRINT "60BPM 0MS RAMP (NO FADE) IN SAW: PLAY " + Q$ + P$ + Q$ : PLAY P$

SOUNDS:
PRINT
PRINT "--- SOUNDS THAT YOU CAN MAKE! ---"
P$ = "V25 T120 L16 O1 @4 <C,@3<<C P4 <C,@3<<C P4 <C,@3<<C P4 <C,@3<<C" : PRINT "BASS DRUM: PLAY " Q$ + P$ + Q$ : PLAY P$
PRINT
P$ = "V2  T120 L64 O6 P4 @1A,@5A P4 @1A,@5A P4 @1A,@5A P4 @1A,@5A" : PRINT "HI HAT: PLAY " Q$ + P$ + Q$ : PLAY P$
PRINT
P$ = "V5  T240 L64 O5 MS @2E,@1E @2A,@1A @2A,@1A @2F,@1F @2E,@1E @2A,@1A @2A,@1A @2F,@1F @2E,@1E @2A,@1A @2A,@1A @2F,@1F @2E,@1E @2A,@1A @2A,@1A @2F,@1F @2E,@1E @2A,@1A @2A,@1A @2F,@1F @2E,@1E @2A,@1A @2A,@1A @2F,@1F P1 @5 L1 O1 Q100 C,C,C,C,@2<<<<C" : PRINT "SQUEAL TIRES AND CRASH: PLAY " Q$ + P$ + Q$ : PLAY P$
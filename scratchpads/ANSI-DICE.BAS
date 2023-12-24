DEFINT i-k, x-z

SCREEN 0
WIDTH 80, 50
_FULLSCREEN _SQUAREPIXELS, _SMOOTH

REDIM SHARED FB(1 TO 10) AS _UNSIGNED _BYTE
FB(&H1) = 176
FB(&H2) = 177
FB(&H3) = 178
FB(&H4) = 219
FB(&H5) = 223
FB(&H6) = 220
FB(&H7) = 221
FB(&H8) = 222
FB(&H9) = 254
FB(&HA) = 250
         ' ASC    UNICODE
CONST F1 = 176 '░ 2591
CONST F2 = 177 '▒ 2592
CONST F3 = 178 '▓ 2593
CONST F4 = 219 '█ 2588
CONST F5 = 223 '▀ 2580
CONST F6 = 220 '▄ 2584
CONST F7 = 221 '▌ 258C
CONST F8 = 222 '▐ 2590
CONST F9 = 254 '■ 25A0
CONST FA = 250 '∙ 2219

FOR i% = LBOUND(FB) TO UBOUND(FB)
    PRINT CHR$(FB(i%));
NEXT i%

DIM D20(1 TO 6) AS STRING
D20$(1) = " 6446 "
D20$(2) = "844447"
D20$(3) = "844447"
D20$(4) = "86  67"
D20$(5) = " 4444 "
D20$(6) = "  55  "

DIM D12(1 TO 6) AS STRING
D12$(1) = "  44  "
D12$(2) = " 4444 "
D12$(3) = " 4444 "
D12$(4) = " 6  6 "
D12$(5) = " 4444 "
D12$(6) = "  55  "

DIM D10(1 TO 6) AS STRING
D10$(1) = "  87  "
D10$(2) = "  44  "
D10$(3) = " 8447 "
D10$(4) = " 8447 "
D10$(5) = "  44  "
D10$(6) = "  87  "

DIM D8(1 TO 6) AS STRING
D8$(1) = "  6    "
D8$(2) = " 847   "
D8$(3) = " 444   "
D8$(4) = " 444   "
D8$(5) = " 847   "
D8$(6) = "  5    "

DIM D6(1 TO 6) AS STRING
D6$(1) = "       "
D6$(2) = " 444   "
D6$(3) = " 444   "
D6$(4) = " 444   "
D6$(5) = " 444   "
D6$(6) = "       "

DIM D4(1 TO 6) AS STRING
D4$(1) = "       "
D4$(2) = "  4    "
D4$(3) = " 847   "
D4$(4) = " 444   "
D4$(5) = "84447  "
D4$(6) = "       "

RANDOMIZE TIMER
PRINT : PRINT
CALL roll_die(D20$(), 20, 15, 4, 8)
CALL roll_die(D12$(), 12, 15, 4, 8)
CALL roll_die(D10$(), 10, 15, 4, 8)
CALL roll_die(D8$(), 8, 15, 4, 8)
CALL roll_die(D6$(), 6, 15, 4, 8)
CALL roll_die(D4$(), 4, 15, 4, 8)

CALL roll_die(D20$(), 20, 0, 7, 8)
CALL roll_die(D12$(), 12, 0, 7, 8)
CALL roll_die(D10$(), 10, 0, 7, 8)
CALL roll_die(D8$(), 8, 0, 7, 8)
CALL roll_die(D6$(), 6, 0, 7, 8)
CALL roll_die(D4$(), 4, 0, 7, 8)

CALL roll_die(D20$(), 20, 10, 6, 8)
CALL roll_die(D12$(), 12, 10, 6, 8)
CALL roll_die(D10$(), 10, 10, 6, 8)
CALL roll_die(D8$(), 8, 10, 6, 8)
CALL roll_die(D6$(), 6, 10, 6, 8)
CALL roll_die(D4$(), 4, 10, 6, 8)

SUB roll_die(display$(), dice_sides~%%, dc_bright~%%, dc_dark~%%, dc_shadow~%%)
    DIM AS _UNSIGNED _BYTE bg, fg', dice_sides, dc_bright, dc_dark, dc_shadow
    DIM AS STRING ds, dl, dr, dls, drs, roll
    FOR i% = LBOUND(display$) TO UBOUND(display$)
        ds$ = to_fb$(display$(i%))
        bg~%% = 0 : fg~%% = dc_dark~%%
        IF i% = 2 THEN
            dls$  = MID$(ds$, 1, 1)
            dl$   = MID$(ds$, 2, 4)
            drs$  = MID$(ds$, 6, 1)
            IF dice_sides~%% >= 12 THEN
                bg~%% = 0 : fg~%% = dc_shadow~%%
                COLOR fg~%%, bg~%% : PRINT dls$;
                bg~%% = dc_dark~%% : fg~%% = dc_dark~%%
                COLOR fg~%%, bg~%% : PRINT dl$;
            ELSEIF dice_sides~%% = 10 THEN
                dls$  = MID$(ds$, 1, 2)
                dl$   = MID$(ds$, 3, 2)
                drs$  = MID$(ds$, 5, 2)
                bg~%% = 0 : fg~%% = dc_shadow~%%
                COLOR fg~%%, bg~%% : PRINT dls$;
                bg~%% = 0 : fg~%% = dc_dark~%%
                COLOR fg~%%, bg~%% : PRINT dl$;
            ELSE
                dls$  = MID$(ds$, 1, 2)
                dl$   = MID$(ds$, 3, 2)
                drs$  = MID$(ds$, 5, 2)
                bg~%% = 0 : fg~%% = dc_dark~%%
                COLOR fg~%%, bg~%% : PRINT dls$;
                bg~%% = 0 : fg~%% = dc_dark~%%
                COLOR fg~%%, bg~%% : PRINT dl$;
            ENDIF
            bg~%% = 0 : fg~%% = dc_shadow~%%
            COLOR fg~%%, bg~%% : PRINT drs$
            _CONTINUE
        ELSEIF i% = 3 THEN 
            dls$  = MID$(ds$, 1, 1)
            dl$   = MID$(ds$, 2, 1)
            dr$   = MID$(ds$, 5, 1)
            drs$  = MID$(ds$, 6, 1)
            roll$ = _TRIM$(STR$(INT(RND(1) * dice_sides~%% + 1)))
            IF dice_sides~%% >= 10 THEN
                IF LEN(roll$) < 2 THEN roll$ = "0" + roll$
            ELSEIF dice_sides~%% >= 6 THEN
                roll$ = roll$ + " "
            END IF
            IF dice_sides~%% > 4 THEN
                COLOR dc_shadow~%% : PRINT dls$;
                COLOR fg~%%, bg~%% : PRINT dl$;
                bg~%% = dc_dark~%% : fg~%% = dc_bright~%%
                COLOR fg~%%, bg~%% : PRINT roll$;
                bg~%% = 0 : fg~%% = dc_dark~%%
                COLOR fg~%%, bg~%% : PRINT dr$;
                COLOR dc_shadow~%% : PRINT drs$
                _CONTINUE
            ELSE
                dls$  = MID$(ds$, 1, 2)
                drs$  = MID$(ds$, 4, 2)
                COLOR dc_dark~%% : PRINT dls$;
                bg~%% = dc_dark~%% : fg~%% = dc_bright~%%
                COLOR fg~%%, bg~%% : PRINT roll$;
                bg~%% = 0 : fg~%% = dc_dark~%%
                COLOR fg~%%, bg~%% : PRINT drs$
                _CONTINUE
            ENDIF
        ELSEIF i% = 4 THEN
            IF dice_sides~%% >= 12 THEN
                dls$  = MID$(ds$, 1, 1)
                dl$   = MID$(ds$, 2, 4)
                drs$  = MID$(ds$, 6, 1) 
                bg~%% = 0 : fg~%% = dc_shadow~%%
                COLOR fg~%%, bg~%% : PRINT dls$;
                bg~%% = dc_dark~%% : fg~%% = dc_shadow~%%
                COLOR fg~%%, bg~%% : PRINT dl$;
                bg~%% = 0 : fg~%% = dc_shadow~%%
                COLOR fg~%%, bg~%% : PRINT drs$
                _CONTINUE
            ELSEIF dice_sides~%% = 10 THEN
                dls$  = MID$(ds$, 1, 2)
                dl$   = MID$(ds$, 3, 2)
                drs$  = MID$(ds$, 5, 2)
                bg~%% = 0 : fg~%% = dc_dark~%%
                COLOR fg~%%, bg~%% : PRINT dls$;
                bg~%% = 0 : fg~%% = dc_dark~%%
                COLOR fg~%%, bg~%% : PRINT dl$;
                bg~%% = 0 : fg~%% = dc_dark~%%
                COLOR fg~%%, bg~%% : PRINT drs$
                _CONTINUE
            ELSE
                bg~%% = 0 : fg~%% = dc_dark~%%
                COLOR fg~%%, bg~%% : PRINT ds$
                _CONTINUE
            ENDIF
        ELSEIF i% > 4 THEN 
            bg~%% = 0 : fg~%% = dc_shadow~%%
        END IF
        COLOR fg~%%, bg~%% : PRINT ds$
    NEXT i%
END SUB

FUNCTION to_fb$(txt$)
    DIM AS STRING s, c
    s$ = ""
    FOR i% = 0 TO LEN(txt$)
        c$ = MID$(txt$, i%, 1)
        SELECT CASE c$
            CASE "1": s$ = s$ + CHR$(F1)
            CASE "2": s$ = s$ + CHR$(F2)
            CASE "3": s$ = s$ + CHR$(F3)
            CASE "4": s$ = s$ + CHR$(F4)
            CASE "5": s$ = s$ + CHR$(F5)
            CASE "6": s$ = s$ + CHR$(F6)
            CASE "7": s$ = s$ + CHR$(F7)
            CASE "8": s$ = s$ + CHR$(F8)
            CASE "9": s$ = s$ + CHR$(F9)
            CASE "A": s$ = s$ + CHR$(FA)
            CASE ELSE: s$ = s$ + c$
        END SELECT
    NEXT i%
    to_fb$ = s$
END FUNCTION
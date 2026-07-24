' TEST-DICE-ROT.bas -- verify _MAPTRIANGLE rotation of a DPoly die glyph.
' Build/run FROM THE REPO ROOT so assets/fonts/dpoly resolves:
'   qb64pe -w -x scratchpads/TEST-DICE-ROT.bas -o TEST-DICE-ROT.run
'   ./TEST-DICE-ROT.run        (renders, saves scratchpads/shots/dice-rot.png, exits)
OPTION _EXPLICIT
DIM SHARED SCRW AS INTEGER, SCRH AS INTEGER
SCRW = 760: SCRH = 240
SCREEN _NEWIMAGE(SCRW, SCRH, 32)
_TITLE "dice rotation test"

DIM fh AS LONG
fh = _LOADFONT("assets/fonts/dpoly/DPoly Twenty-Sider.otf", 56)
IF fh <= 0 THEN PRINT "font load failed": _DELAY 1: SYSTEM

DIM body AS _UNSIGNED LONG, ink AS _UNSIGNED LONG
body = _RGB32(&HEF, &HE6, &HC8)      ' bone
ink = _RGB32(&H30, &H20, &H10)       ' dark number

' scratch image the die is rendered into (transparent), then rotated from
DIM SCR_W AS INTEGER, SCR_H AS INTEGER
SCR_W = 140: SCR_H = 180
DIM scratch AS LONG
scratch = _NEWIMAGE(SCR_W, SCR_H, 32)

' render die face 17 = glyph 'Q' (65+16 solid, 97+16 outline) centred in scratch
RenderDie scratch, fh, body, ink, 16, SCR_W, SCR_H

_DEST 0
CLS , _RGB32(&H20, &H00, &H00)

DIM angles(1 TO 5) AS SINGLE, i AS INTEGER, cx AS SINGLE
angles(1) = 0: angles(2) = 20: angles(3) = 45: angles(4) = 70: angles(5) = 90
FOR i = 1 TO 5
    cx = 76 + (i - 1) * 152
    RotoBlit scratch, SCR_W, SCR_H, cx, SCRH \ 2, angles(i) * 3.14159265 / 180, 0
NEXT i

_DISPLAY
_SAVEIMAGE "scratchpads/shots/dice-rot.png"
SYSTEM


SUB RenderDie (img AS LONG, fh AS LONG, body AS _UNSIGNED LONG, ink AS _UNSIGNED LONG, code AS INTEGER, w AS INTEGER, h AS INTEGER)
    DIM od AS LONG, ox AS INTEGER, oy AS INTEGER
    od = _DEST
    _DEST img
    CLS , _RGBA32(0, 0, 0, 0)             ' transparent
    _FONT fh
    _PRINTMODE _KEEPBACKGROUND
    ' rough centre (the glyph draws its top vertex above the pen, so nudge down)
    ox = (w - _UPRINTWIDTH("A")) \ 2
    oy = (h - _FONTHEIGHT(fh)) \ 2 + _FONTHEIGHT(fh) \ 4
    COLOR body, _RGBA32(0, 0, 0, 0): _UPRINTSTRING (ox, oy), CHR$(65 + code)
    COLOR ink, _RGBA32(0, 0, 0, 0): _UPRINTSTRING (ox, oy), CHR$(97 + code)
    _PRINTMODE _FILLBACKGROUND
    _DEST od
END SUB


' Rotate WxH image `src` around its own centre, draw centred at (cx,cy) on dst.
SUB RotoBlit (src AS LONG, w AS INTEGER, h AS INTEGER, cx AS SINGLE, cy AS SINGLE, ang AS SINGLE, dst AS LONG)
    DIM ca AS SINGLE, sa AS SINGLE, hw AS SINGLE, hh AS SINGLE, od AS LONG
    DIM x1 AS SINGLE, y1 AS SINGLE, x2 AS SINGLE, y2 AS SINGLE
    DIM x3 AS SINGLE, y3 AS SINGLE, x4 AS SINGLE, y4 AS SINGLE
    ca = COS(ang): sa = SIN(ang)
    hw = w / 2: hh = h / 2
    x1 = cx + (-hw) * ca - (-hh) * sa: y1 = cy + (-hw) * sa + (-hh) * ca   ' TL
    x2 = cx + (hw) * ca - (-hh) * sa: y2 = cy + (hw) * sa + (-hh) * ca     ' TR
    x3 = cx + (hw) * ca - (hh) * sa: y3 = cy + (hw) * sa + (hh) * ca       ' BR
    x4 = cx + (-hw) * ca - (hh) * sa: y4 = cy + (-hw) * sa + (hh) * ca     ' BL
    od = _DEST: _DEST dst
    _MAPTRIANGLE (0, 0)-(w - 1, 0)-(w - 1, h - 1), src TO (x1, y1)-(x2, y2)-(x3, y3)
    _MAPTRIANGLE (0, 0)-(w - 1, h - 1)-(0, h - 1), src TO (x1, y1)-(x3, y3)-(x4, y4)
    _DEST od
END SUB

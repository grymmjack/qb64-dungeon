'From https://web.archive.org/web/20120204063040/http://www.acid.org/info/xbin/x_spec.htm
' xbin kit here: https://github.com/radman1/xbin/tree/master

'typedef struct XB_Header {
'   unsigned char   ID[4];
'   unsigned char   EofChar;
'   unsigned short  Width;
'   unsigned short  Height;
'   unsigned char   Fontsize;
'   unsigned char   Flags;
'};

TYPE XBIN_HEADER
    ID       AS STRING * 4
    EOFChar  AS _UNSIGNED _BYTE
    Width    AS _UNSIGNED INTEGER
    Height   AS _UNSIGNED INTEGER
    Fontsize AS _UNSIGNED _BYTE
    Flags    AS _UNSIGNED BYTE
END TYPE

DIM AS _BIT _
    XBIN_IS_PALETTE_PRESENT, _
    XBIN_IS_FONT_PRESENT, _
    XBIN_IS_COMPRESSED, _
    XBIN_IS_ICE_COLORS, _
    XBIN_IS_512_CHAR_MODE

XBIN_IS_PALETTE_PRESENT = ABS((XBIN_HEADER_FLAGS AND 2^0) > 0)
XBIN_IS_FONT_PRESENT    = ABS((XBIN_HEADER_FLAGS AND 2^1) > 0)
XBIN_IS_COMPRESSED      = ABS((XBIN_HEADER_FLAGS AND 2^2) > 0)
XBIN_IS_ICE_COLORS      = ABS((XBIN_HEADER_FLAGS AND 2^3) > 0)
XBIN_IS_512_CHAR_MODE   = ABS((XBIN_HEADER_FLAGS AND 2^4) > 0)

TYPE XBIN_PAL
    R AS _UNSIGNED _BYTE
    G AS _UNSIGNED _BYTE
    B AS _UNSIGNED _BYTE
END TYPE
DIM XBIN_PALETTE(1 TO 16) AS XBIN_PAL

TYPE XBIN_IMAGE_DATA
    CHAR AS _UNSIGNED _BYTE
    ATTR AS _UNSIGNED _BYTE
END TYPE

XBIN_IMAGE_DATA_SIZE = XBIN_HEADER_WIDTH * XBIN_HEADER_HEIGHT * 2

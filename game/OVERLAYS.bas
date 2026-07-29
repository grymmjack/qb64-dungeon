' ============================================================================
'  OVERLAYS.bas -- GAME-side board overlays, drawn on top of the engine's board.
'
'  These render DUNGEON!-specific markers from GAME state (ROOMS / CHM_* / LBL_*):
'  room labels, cleared-room tombstones, chamber graves, and the monster/body/loot
'  glyphs. They lived in engine/BOARD.bas + engine/CURSOR.bas but named game symbols;
'  moved here so the engine's cursor_erase/cursor_draw reach them ONLY through the
'  Game_RenderMapLabels / Game_RenderOverlays hooks below (clears 3 boundary-debt lines).
'  They still call engine drawing primitives (LINE / PutLabel / _PRINTSTRING / VIS /
'  LOS_SEEN) -- the sanctioned game->engine direction.
' ============================================================================

' Game render hook -- the MAP-layer room labels (part of the board; drawn UNDER the
' near-death blood so they dim with it). engine cursor_erase calls this.
SUB Game_RenderMapLabels
    render_room_labels
END SUB

' Game render hook -- the ON-TOP overlays: cleared-room tombstones, chamber graves,
' and the monster/body/loot glyphs. engine cursor_draw calls this.
SUB Game_RenderOverlays
    DrawTombstones
    DrawChamberGraves
    DrawEntities
END SUB

SUB render_room_labels
    DIM AS _UNSIGNED LONG b, r
    DIM i AS INTEGER, fg AS _UNSIGNED LONG
    b = _RGB32(&H00, &H00, &HAA): r = _RGB32(&HFF, &H55, &H55)
    _DEST CANVAS
    FOR i = 1 TO LBL_N
        IF LBL_T(i) = "START" THEN fg = r ELSE fg = b
        PutLabel LBL_X(i), LBL_Y(i), LBL_T(i), fg
    NEXT i
END SUB
' Draw a small grey headstone on every room whose monster has been slain, so the
' board shows at a glance which rooms are cleared. (Rendered onto CANVAS after a
' fresh board blit, so it rides along with cursor_draw.)
SUB DrawTombstones
    DIM r AS INTEGER, px AS INTEGER, py AS INTEGER, gx AS INTEGER, gy AS INTEGER
    DIM grave AS _UNSIGNED LONG, dark AS _UNSIGNED LONG
    grave = _RGB32(&HC8, &HC8, &HC8): dark = _RGB32(&H30, &H30, &H30)
    _DEST CANVAS
    ' Headstones only. Loot markers (the fallen-body ☻ and the recoverable-$ glyph)
    ' are drawn by DrawEntities, which runs after this and matches the board legend.
    ' Sit the grave on the SAME label-avoiding cell the § monster used (EntityDrawX/Y),
    ' so the headstone lands exactly where the monster stood -- never off under a label.
    FOR r = 1 TO ROOM_N
        gx = EntityDrawX(r): gy = EntityDrawY(r)
        IF VIS(gx, gy) AND (NOT opt_fov OR LOS_SEEN(gx, gy)) THEN
            px = gx * CW: py = gy * CH
            IF ROOMS(r).monster_fought AND NOT ROOMS(r).malive THEN
                LINE (px + 1, py + 5)-(px + CW - 2, py + CH - 1), grave, BF     ' stone body
                LINE (px + 2, py + 3)-(px + CW - 3, py + 6), grave, BF          ' rounded top
                LINE (px + CW \ 2, py + 6)-(px + CW \ 2, py + CH - 3), dark     ' cross (vertical)
                LINE (px + 2, py + 9)-(px + CW - 3, py + 9), dark               ' cross (horizontal)
            END IF
        END IF
    NEXT r
END SUB
' Grey headstones for chamber monsters slain -- one per grave (up to CHM_DEAD, max 3).
SUB DrawChamberGraves
    DIM cid AS INTEGER, k AS INTEGER, gx AS INTEGER, gy AS INTEGER, px AS INTEGER, py AS INTEGER
    DIM grave AS _UNSIGNED LONG, dark AS _UNSIGNED LONG
    grave = _RGB32(&HC8, &HC8, &HC8): dark = _RGB32(&H30, &H30, &H30)
    _DEST CANVAS
    FOR cid = 1 TO NCHAMBER
        IF CHM_DEAD(cid) > 0 AND CHAMBERAT(START_CX, START_CY) <> cid THEN
            FOR k = 1 TO CHM_DEAD(cid)
                gx = CHM_GX(cid, k): gy = CHM_GY(cid, k)
                IF VIS(gx, gy) AND (NOT opt_fov OR LOS_SEEN(gx, gy)) THEN
                    px = gx * CW: py = gy * CH
                    LINE (px + 1, py + 5)-(px + CW - 2, py + CH - 1), grave, BF   ' stone body
                    LINE (px + 2, py + 3)-(px + CW - 3, py + 6), grave, BF        ' rounded top
                    LINE (px + CW \ 2, py + 6)-(px + CW \ 2, py + CH - 3), dark   ' cross (vertical)
                    LINE (px + 2, py + 9)-(px + CW - 3, py + 9), dark             ' cross (horizontal)
                END IF
            NEXT k
        END IF
    NEXT cid
END SUB
' Honours Field of View: with FOV off, every monster shows (so you can plan / spot
' random spawns); with FOV on, only rooms you have actually explored (LOS_SEEN) reveal.
SUB DrawEntities
    DIM r AS INTEGER, gx AS INTEGER, gy AS INTEGER, vis AS INTEGER
    _DEST CANVAS
    _FONT CH
    FOR r = 1 TO ROOM_N
        gx = ROOMS(r).cx: gy = ROOMS(r).cy
        IF gx >= 0 AND gy >= 0 AND gx <= 131 AND gy <= 60 THEN
            gx = EntityDrawX(r): gy = EntityDrawY(r)   ' shift off any level label under the marker
            vis = FALSE
            ' Monsters stay hidden until the player has actually ENTERED their room
            ' (no board-wide reveal), and -- in FOV mode -- until that spot is seen.
            IF ROOMS(r).seen THEN
                vis = TRUE
                IF opt_fov THEN IF LOS_SEEN(gx, gy) = 0 THEN vis = FALSE
            END IF
            IF vis THEN
                ' Body first: an adventurer who fell here left spoils on the ground, and
                ' the monster that felled them is usually still alive -- so this must beat
                ' the live-monster glyph, or a death room would just show its § again.
                IF ROOMS(r).player_died AND HasDrop(r) THEN
                    COLOR _RGB32(&HE0, &H33, &H33), BLACK                      ' ☻ a fallen adventurer's body, blood red -- loot on the ground
                    _PRINTSTRING (gx * CW, gy * CH), CHR$(2)
                ELSEIF ROOMS(r).malive AND LEN(_TRIM$(ROOMS(r).monster)) > 0 THEN
                    COLOR _RGB32(&HFF, &H55, &H55), _RGB32(&H55, &HFF, &HFF)   ' § monster: red on cyan
                    _PRINTSTRING (gx * CW, gy * CH), CHR$(21)
                ELSEIF HasDrop(r) THEN
                    COLOR _RGB32(&H55, &HFF, &H55), BLACK                      ' $ recoverable treasure (e.g. a curio left unopened): green
                    _PRINTSTRING (gx * CW, gy * CH), "$"
                END IF
            END IF
        END IF
    NEXT r
    ' loose spoils out on the open paths (a fall in the corridors, no room to hold it):
    ' the same blood-red body marker, keyed to the exact cell, FOV-aware.
    FOR r = 1 TO UBOUND(LOOSE)
        IF LOOSE(r).active THEN
            gx = LOOSE(r).cx: gy = LOOSE(r).cy
            IF gx >= 0 AND gy >= 0 AND gx <= 131 AND gy <= 60 THEN
                vis = TRUE
                IF opt_fov THEN IF LOS_SEEN(gx, gy) = 0 THEN vis = FALSE
                IF vis THEN
                    COLOR _RGB32(&HE0, &H33, &H33), BLACK
                    _PRINTSTRING (gx * CW, gy * CH), CHR$(2)
                END IF
            END IF
        END IF
    NEXT r
END SUB


' A room's marker cell can land under a level label; these find the nearest cell
' of the SAME room that no label prints on, so the monster/loot glyph never sits
' on top of "8th", "TORTURE CHAMBER", etc. Falls back to the marker if none clear.
FUNCTION EntityDrawX% (r AS INTEGER)
    DIM ox AS INTEGER, oy AS INTEGER
    EntityShiftFind r, ox, oy
    EntityDrawX = ox
END FUNCTION
FUNCTION EntityDrawY% (r AS INTEGER)
    DIM ox AS INTEGER, oy AS INTEGER
    EntityShiftFind r, ox, oy
    EntityDrawY = oy
END FUNCTION
SUB EntityShiftFind (r AS INTEGER, ox AS INTEGER, oy AS INTEGER)
    DIM bx AS INTEGER, by AS INTEGER, rad AS INTEGER, dx AS INTEGER, dy AS INTEGER, nx AS INTEGER, ny AS INTEGER
    bx = ROOMS(r).cx: by = ROOMS(r).cy
    ox = bx: oy = by
    IF bx < 0 OR by < 0 OR bx > 131 OR by > 60 THEN EXIT SUB
    IF LABELMASK(bx, by) = 0 THEN EXIT SUB          ' marker is already clear of any label
    FOR rad = 1 TO 3                                ' spiral out to a same-room, label-free cell
        FOR dy = -rad TO rad
            FOR dx = -rad TO rad
                nx = bx + dx: ny = by + dy
                IF nx >= 0 AND ny >= 0 AND nx <= 131 AND ny <= 60 THEN
                    IF ROOMAT(nx, ny) = r AND LABELMASK(nx, ny) = 0 THEN
                        ox = nx: oy = ny: EXIT SUB
                    END IF
                END IF
            NEXT dx
        NEXT dy
    NEXT rad
END SUB

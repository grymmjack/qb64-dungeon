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
    DrawHunter                  ' Monster Prey: the pursuing hunter token (solo mode)
    DrawPlayerTokens            ' rivals, then the active seat at the cursor -- LAST, on top
END SUB

' The hot-seat player tokens, each drawn as its SEAT NUMBER. Rivals first (white on that
' seat's colour, hidden by FOV until lit), then the ACTIVE seat at the engine's cursor
' position on legend-blue -- matching the board's "# Player #" key.
'
' This was inlined in engine/cursor_draw, which meant the engine named PLAYERS()/num_players/
' cur_player. The engine owns where the cursor is; what the marker LOOKS like -- and that it
' carries a seat number at all -- is this game's presentation.
SUB DrawPlayerTokens
    DIM p AS INTEGER
    _DEST CANVAS
    IF num_players > 1 THEN
        FOR p = 1 TO num_players
            IF p <> cur_player AND PLAYERS(p).active THEN
                IF NOT opt_fov OR LOS_LIT(PLAYERS(p).cx \ CW, PLAYERS(p).cy \ CH) THEN
                    _FONT CH: COLOR WHITE, PLAYERS(p).kolor
                    _PRINTSTRING (PLAYERS(p).cx, PLAYERS(p).cy), _TRIM$(STR$(p))
                END IF
            END IF
        NEXT p
    END IF
    _FONT CH: COLOR WHITE, _RGB32(&H55, &H55, &HFF)
    _PRINTSTRING (c.x, c.y), _TRIM$(STR$(cur_player))
END SUB

' --- the board's room-label TABLE (moved from engine/BOARD.bas) ---------------
' The labels are one data table (LBL_*) read from assets/data/labels.txt (col | row |
' text -- edit + F5), used both to RENDER them (render_room_labels, below) and to build
' LABELMASK so monster glyphs can be steered clear of the label cells. That makes them
' game CONTENT, so they live here with the renderer that consumes them; the engine keeps
' only PutLabel, the draw primitive. CHAMBERS.bas also seeds off LBL_* (game->game).
SUB InitLabels
    LBL_N = 0
    LoadLabels
    BuildLabelMask
END SUB

SUB LoadLabels
    DIM i AS INTEGER, txt AS STRING
    ReadDataFile "assets/data/labels.txt"
    FOR i = 1 TO DLINE_N
        txt = DField$(DLINE(i), 3)
        IF LEN(txt) > 0 THEN AddLabel VAL(DField$(DLINE(i), 1)), VAL(DField$(DLINE(i), 2)), txt
    NEXT i
END SUB

SUB AddLabel (cx AS INTEGER, cy AS INTEGER, txt AS STRING)
    IF LBL_N >= UBOUND(LBL_X) THEN EXIT SUB
    LBL_N = LBL_N + 1
    LBL_X(LBL_N) = cx: LBL_Y(LBL_N) = cy: LBL_T(LBL_N) = txt
END SUB

' Mark every cell a label prints over (plus one cell of padding) so DrawEntities
' can steer monster glyphs clear of the level labels.
SUB BuildLabelMask
    DIM i AS INTEGER, x AS INTEGER, cx AS INTEGER, cy AS INTEGER
    FOR cy = 0 TO 60
        FOR cx = 0 TO 131: LABELMASK(cx, cy) = 0: NEXT cx
    NEXT cy
    FOR i = 1 TO LBL_N
        cy = LBL_Y(i)
        FOR x = LBL_X(i) - 1 TO LBL_X(i) + LEN(LBL_T(i))    ' -1/+len = one cell of padding each side
            IF x >= 0 AND x <= 131 AND cy >= 0 AND cy <= 60 THEN LABELMASK(x, cy) = -1
        NEXT x
    NEXT i
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
    DIM r AS INTEGER, gx AS INTEGER, gy AS INTEGER, vis AS INTEGER, last AS INTEGER
    _DEST CANVAS
    _FONT CH
    ' Past ROOM_N sit the SCRATCH encounter slots -- the wandering monster (ROOM_N+1, also the
    ' MIMIC), the chamber guardian (+2) and a damage-over-time death (+3). They are ordinary
    ' ROOMS() records fought by the ordinary combat code, but nothing ever DREW them, so a
    ' wanderer or chamber monster you fled stayed on the board invisibly and the spot you fell
    ' on carried no marker. They now carry a real cell (set by their spawners) and render here
    ' with everything else. ROOMAT never maps them, so they still cannot be walked into.
    last = ROOM_N + 3: IF last > UBOUND(ROOMS) THEN last = UBOUND(ROOMS)
    FOR r = 1 TO last
        gx = ROOMS(r).cx: gy = ROOMS(r).cy
        IF gx >= 0 AND gy >= 0 AND gx <= 131 AND gy <= 60 THEN
            ' Only a real room can shift its marker off a level label -- EntityShiftFind hunts
            ' for a same-room cell via ROOMAT, which a scratch slot is never in.
            IF r <= ROOM_N THEN gx = EntityDrawX(r): gy = EntityDrawY(r)
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

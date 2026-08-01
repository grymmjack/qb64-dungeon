' ============================================================================
'  CTEXT.bas -- per-monster and per-class COMBAT EVENT text (data-driven)
'
'  Every monster and every class can have its own lines for five events:
'    attack  -- it lands a blow          miss  -- its blow goes wide
'    crit    -- a devastating hit        fumble-- it botches its swing
'    death   -- it is slain / downed
'  so a GREEN SLIME dissolves you and a RED DRAGON immolates you, instead of both
'  "clawing". Files (edit + F5, no code change):
'    assets/flavor/monster_events.txt   key = monster NAME
'    assets/flavor/class_events.txt     key = class NAME (HERO/ELF/SUPERHERO/WIZARD)
'  Format:  key | event | text     (fields trimmed; '#' comment; blank lines skipped)
'  key "*" is the DEFAULT used for any monster/class with no line of its own for that
'  event, so you only need to write specific lines where they matter. Up to a handful
'  of lines per (key,event) -- one is picked at random each time.
'
'  Tokens filled in the text by Fill$:
'    {player} champion's name (or "you")   {class} class name      {mon} monster name
'    {dmg} damage this event               {deaths} times you've died
'    {level} dungeon level (1-9)           {room} room label
'    {treasure} treasure name              {item}/{weapon} your weapon
' ============================================================================

' Map an event word to its code (0 = unknown).
FUNCTION EvtCode% (s AS STRING)
    SELECT CASE UCASE$(_TRIM$(s))
        CASE "ATTACK": EvtCode = 1
        CASE "MISS": EvtCode = 2
        CASE "CRIT": EvtCode = 3
        CASE "FUMBLE": EvtCode = 4
        CASE "DEATH": EvtCode = 5
        CASE "KILLCRIT": EvtCode = 6                ' slain BY A CRIT -- the aftermath, not the blow
        CASE ELSE: EvtCode = 0
    END SELECT
END FUNCTION

' How the {player} token reads: the champion's name if they have one, else "you".
FUNCTION PlayerRef$
    IF LEN(_TRIM$(player_name)) > 0 THEN PlayerRef$ = _TRIM$(player_name) ELSE PlayerRef$ = "you"
END FUNCTION

' TRUE if a monster name is grammatically PLURAL ("GIANT RATS", "GHOULS"): it ends
' in S but not SS. Every singular monster in the roster ends in another letter, so
' this cleanly separates the packs from the lone beasts.
FUNCTION MonPlural% (nm AS STRING)
    DIM s AS STRING
    s = UCASE$(_TRIM$(nm))
    MonPlural% = 0
    IF LEN(s) >= 2 THEN
        IF RIGHT$(s, 1) = "S" AND RIGHT$(s, 2) <> "SS" THEN MonPlural% = -1
    END IF
END FUNCTION

' Subject-verb agreement for a monster name: pick the singular or plural verb form
' ("The GIANT RATS ARE slain" vs "The SKELETON IS slain"). For hand-built code lines.
FUNCTION MonVerb$ (nm AS STRING, sing AS STRING, plur AS STRING)
    IF MonPlural%(nm) THEN MonVerb$ = plur ELSE MonVerb$ = sing
END FUNCTION

' Substitute every {token} in a template from the current flavor context + globals.
FUNCTION Fill$ (s AS STRING)
    DIM r AS STRING, dc AS INTEGER
    r = _TRIM$(s)
    IF cur_player >= 1 AND cur_player <= 4 THEN dc = deaths(cur_player) ELSE dc = deaths(1)
    r = StrSubst$(r, "{player}", PlayerRef$)
    r = StrSubst$(r, "{class}", _TRIM$(class_name))
    r = StrSubst$(r, "{mon}", _TRIM$(FX_MON))
    r = StrSubst$(r, "{dmg}", _TRIM$(STR$(FX_DMG)))
    r = StrSubst$(r, "{deaths}", _TRIM$(STR$(dc)))
    r = StrSubst$(r, "{level}", _TRIM$(STR$(FX_LEVEL)))
    r = StrSubst$(r, "{room}", _TRIM$(FX_ROOM))
    r = StrSubst$(r, "{treasure}", _TRIM$(FX_TREASURE))
    r = StrSubst$(r, "{item}", WeaponName$)
    r = StrSubst$(r, "{weapon}", WeaponName$)
    ' grammar tokens -- resolve verb agreement for the monster (packs read plural):
    '   lunge{s}  press{es}  {it}/{its}  {is}=is/are  {was}=was/were  {has}=has/have
    IF MonPlural%(FX_MON) THEN
        r = StrSubst$(r, "{s}", ""): r = StrSubst$(r, "{es}", "")
        r = StrSubst$(r, "{is}", "are"): r = StrSubst$(r, "{was}", "were"): r = StrSubst$(r, "{has}", "have")
        r = StrSubst$(r, "{its}", "their"): r = StrSubst$(r, "{it}", "they")
    ELSE
        r = StrSubst$(r, "{s}", "s"): r = StrSubst$(r, "{es}", "es")
        r = StrSubst$(r, "{is}", "is"): r = StrSubst$(r, "{was}", "was"): r = StrSubst$(r, "{has}", "has")
        r = StrSubst$(r, "{its}", "its"): r = StrSubst$(r, "{it}", "it")
    END IF
    Fill$ = r
END FUNCTION

' Load one event-text file into EVT() with the given category (1 monster, 2 class).
SUB LoadEventText (path AS STRING, cat AS INTEGER)
    DIM i AS INTEGER, ec AS INTEGER
    ReadDataFile path
    FOR i = 1 TO DLINE_N
        ec = EvtCode(DField$(DLINE(i), 2))
        IF ec > 0 THEN
            IF EVT_N < UBOUND(EVT) THEN
                EVT_N = EVT_N + 1
                EVT(EVT_N).cat = cat
                EVT(EVT_N).mkey = UCASE$(DField$(DLINE(i), 1))
                EVT(EVT_N).evt = ec
                EVT(EVT_N).text = DField$(DLINE(i), 3)
                EVT(EVT_N).nkey = DField$(DLINE(i), 4)      ' optional; "" = shown but never spoken
            END IF
        END IF
    NEXT i
END SUB

SUB InitCombatText
    EVT_N = 0
    LoadEventText "assets/flavor/monster_events.txt", 1
    LoadEventText "assets/flavor/class_events.txt", 2
END SUB

' A random event line for (cat, key, evt), tokens filled. Falls back to the "*"
' default key, then to "" if nothing matches (caller then keeps its own text).
FUNCTION EventLine$ (cat AS INTEGER, kk AS STRING, evt AS INTEGER)
    DIM idx(1 TO 40) AS INTEGER, ni AS INTEGER, i AS INTEGER, ky AS STRING
    ky = UCASE$(_TRIM$(kk))
    ni = 0
    FOR i = 1 TO EVT_N
        IF EVT(i).cat = cat THEN
            IF EVT(i).evt = evt THEN
                IF UCASE$(_TRIM$(EVT(i).mkey)) = ky THEN
                    IF ni < UBOUND(idx) THEN ni = ni + 1: idx(ni) = i
                END IF
            END IF
        END IF
    NEXT i
    IF ni = 0 THEN                                   ' fall back to the "*" default
        FOR i = 1 TO EVT_N
            IF EVT(i).cat = cat THEN
                IF EVT(i).evt = evt THEN
                    IF _TRIM$(EVT(i).mkey) = "*" THEN
                        IF ni < UBOUND(idx) THEN ni = ni + 1: idx(ni) = i
                    END IF
                END IF
            END IF
        NEXT i
    END IF
    IF ni = 0 THEN EventLine$ = "": FX_NARRKEY = "": EXIT FUNCTION
    DIM pick AS INTEGER
    pick = idx(RollDie(ni))
    FX_NARRKEY = _TRIM$(EVT(pick).nkey)              ' set EVERY time, even to "" -- see GAME.BI
    EventLine$ = Fill$(_TRIM$(EVT(pick).text))
END FUNCTION

' Show a combat banner whose BODY is a random (cat,key,evt) flavor line -- or the
' given fallback text if that key/event has no line. Title carries the mechanics.
SUB EventBanner (title AS STRING, cat AS INTEGER, kk AS STRING, evt AS INTEGER, fallback AS STRING)
    DIM fl AS STRING, nk AS STRING
    fl = EventLine$(cat, kk, evt)
    nk = FX_NARRKEY                                  ' capture BEFORE the fallback clears the picture
    IF LEN(fl) = 0 THEN fl = fallback: nk = ""       ' the fallback is code text -- nothing recorded it
    Banner title, fl + "   [ press any key ]"
    IF LEN(nk) > 0 THEN Narrate nk                   ' speak the very line on screen, if a pack has it
END SUB

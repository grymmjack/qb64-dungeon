' ============================================================================
'  MUSIC.bas -- per-level in-game music (data-driven, quality-laddered)
'
'  assets/music/playlist.txt maps each dungeon level (1-9) to a track by BARE NAME
'  (no extension). ResolveMusic$ then plays the HIGHEST-quality file that exists for
'  that name on disk, following a worst -> best ladder:
'
'      .mid -> .rad -> .s3m / .mod / .xm / .it -> .ogg / .mp3 -> .flac -> .wav
'
'  So the repo can ship tiny .mid/.rad tracks and a downloadable "music pack" of
'  .ogg/.wav files upgrades them in place -- just drop the better file into
'  assets/music/ (same base name), no playlist or code change. Nothing on disk for a
'  name -> silence. As you cross into a new level the track switches; levels sharing a
'  name don't restart it, and a level with no playlist line keeps whatever's playing.
'  (An entry that still carries an extension, e.g. "everdark.rad", also resolves --
'  the extension is stripped first, then the ladder picks the best available.)
' ============================================================================

SUB LoadPlaylist
    DIM i AS INTEGER, lv AS INTEGER
    FOR i = 1 TO 9: MUSIC_FILE(i) = "": NEXT i
    music_level = 0: music_curfile = ""
    ReadDataFile "assets/music/playlist.txt"
    FOR i = 1 TO DLINE_N
        lv = VAL(DField$(DLINE(i), 1))
        IF lv >= 1 AND lv <= 9 THEN MUSIC_FILE(lv) = DField$(DLINE(i), 2)
    NEXT i
END SUB

' Ensure level lv's track is the one playing. Cheap to call every step: it returns
' immediately unless the FILE actually needs to change. lv outside 1-9 (an unmapped
' hallway) leaves the current track alone.
SUB PlayLevelMusic (lv AS INTEGER)
    DIM fn AS STRING, path AS STRING
    IF NOT opt_music THEN EXIT SUB                  ' music switched off entirely
    IF lv < 1 OR lv > 9 THEN EXIT SUB              ' unknown area -> keep the current track
    fn = _TRIM$(MUSIC_FILE(lv))
    IF LEN(fn) = 0 THEN EXIT SUB                    ' no track assigned for this level -> keep current
    music_level = lv
    IF fn = music_curfile THEN EXIT SUB            ' this entry already resolved/playing -> nothing to do
    ' the entry changed: stop the old track and resolve the best file for the new name
    IF music_handle > 0 THEN _SNDSTOP music_handle: _SNDCLOSE music_handle: music_handle = 0
    music_curfile = fn                              ' remember the ENTRY so we don't re-resolve every step
    path = ResolveMusic$(fn)                        ' bare name -> best-quality file on disk ("" = none)
    IF LEN(path) = 0 THEN EXIT SUB                  ' nothing on disk for this name -> silence
    music_handle = _SNDOPEN(path)
    IF music_handle > 0 THEN
        _SNDVOL music_handle, opt_musicvol / 10
        _SNDLOOP music_handle
    END IF
END SUB

' Resolve a BARE track name to the highest-quality file that exists for it, per the
' worst -> best ladder (.mid .rad | .s3m .mod .xm .it | .ogg .mp3 | .flac .wav): the
' rightmost existing file wins, so higher-fidelity "packs" dropped into assets/music/
' override the shipped low-fi track with no other change. "" if none exists (silence).
' Any extension already on the name is stripped first, so old-style entries still work.
FUNCTION ResolveMusic$ (nm AS STRING)
    DIM exts(1 TO 10) AS STRING, i AS INTEGER, b AS STRING, chosen AS STRING, p AS STRING
    exts(1) = ".mid": exts(2) = ".rad"
    exts(3) = ".s3m": exts(4) = ".mod": exts(5) = ".xm": exts(6) = ".it"
    exts(7) = ".ogg": exts(8) = ".mp3"
    exts(9) = ".flac": exts(10) = ".wav"
    b = _TRIM$(nm)
    ' strip a trailing known extension (so "everdark.rad" resolves by its base name)
    FOR i = 1 TO 10
        IF LEN(b) > LEN(exts(i)) THEN
            IF LCASE$(RIGHT$(b, LEN(exts(i)))) = exts(i) THEN b = LEFT$(b, LEN(b) - LEN(exts(i))): EXIT FOR
        END IF
    NEXT
    ' keep the last (highest-quality) file that exists
    chosen = ""
    FOR i = 1 TO 10
        p = "assets/music/" + b + exts(i)
        IF _FILEEXISTS(p) THEN chosen = p
    NEXT
    ResolveMusic$ = chosen
END FUNCTION

' Stop and release the in-game track (called when a run ends, before the menu music).
SUB StopLevelMusic
    IF music_handle > 0 THEN _SNDSTOP music_handle: _SNDCLOSE music_handle
    music_handle = 0: music_level = 0: music_curfile = ""
END SUB


' ----------------------------------------------------------------------------
'  Optional file-based sound effects. Drop assets/sfx/<name>.ogg (or .mp3/.wav/
'  .flac) next to a beeper effect and it plays that file instead; any effect with
'  no file keeps its built-in tone. <name> is the Sfx name: move, bump, hit, crit,
'  treasure, chest, boom, ... (see the SELECT CASE in Sfx). Preloaded once here;
'  Sfx plays copies so rapid effects overlap. Honors the SFX Vol slider.
' ----------------------------------------------------------------------------
SUB InitSfxFiles
    SFX_N = 0
    RegisterSfx "move": RegisterSfx "bump": RegisterSfx "door": RegisterSfx "strongdoor"
    RegisterSfx "breakdoor": RegisterSfx "secret": RegisterSfx "secretpass": RegisterSfx "key"
    RegisterSfx "idle": RegisterSfx "treasure": RegisterSfx "trap": RegisterSfx "hit"
    RegisterSfx "miss": RegisterSfx "crit": RegisterSfx "fumble": RegisterSfx "search"
    RegisterSfx "win": RegisterSfx "lose": RegisterSfx "saveok": RegisterSfx "savebad"
    RegisterSfx "chest": RegisterSfx "boom": RegisterSfx "hiss": RegisterSfx "fizzle"
    RegisterSfx "alarm": RegisterSfx "select": RegisterSfx "levelup"
    RegisterSfx "diceroll": RegisterSfx "diceland"      ' 3D-dice throw / land cues
    RegisterSfx "dice_edge": RegisterSfx "dice_settle"  ' optional per-bounce clack + settle for the 3D dice
END SUB

' Load the first existing assets/sfx/<nm>.<ext> into the SFX map (silent if none exist).
SUB RegisterSfx (nm AS STRING)
    DIM h AS LONG, b AS STRING
    b = "assets/sfx/" + nm
    h = 0
    IF _FILEEXISTS(b + ".ogg") THEN h = _SNDOPEN(b + ".ogg")
    IF h <= 0 THEN IF _FILEEXISTS(b + ".mp3") THEN h = _SNDOPEN(b + ".mp3")
    IF h <= 0 THEN IF _FILEEXISTS(b + ".wav") THEN h = _SNDOPEN(b + ".wav")
    IF h <= 0 THEN IF _FILEEXISTS(b + ".flac") THEN h = _SNDOPEN(b + ".flac")
    IF h > 0 THEN
        IF SFX_N < UBOUND(SFX_NAME) THEN SFX_N = SFX_N + 1: SFX_NAME(SFX_N) = nm: SFX_HND(SFX_N) = h
    END IF
END SUB

' Handle of the loaded file for Sfx name nm, or 0 if none (caller then beeps).
FUNCTION SfxHandle& (nm AS STRING)
    DIM i AS INTEGER
    SfxHandle = 0
    FOR i = 1 TO SFX_N
        IF SFX_NAME(i) = nm THEN SfxHandle = SFX_HND(i): EXIT FUNCTION
    NEXT i
END FUNCTION

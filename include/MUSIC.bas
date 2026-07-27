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
'  assets/music/ (same bpath name), no playlist or code change. Nothing on disk for a
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
    DIM b AS STRING, chosen AS STRING
    b = MusicBaseName$(nm)                          ' strip any trailing known extension
    ' selected MUSIC PACK wins; if it has no file for this name, fall back to the flat main dir
    chosen = ""
    IF LEN(opt_musicpack) > 0 THEN chosen = ResolveMusicIn$("assets/music/" + opt_musicpack + "/", b)
    IF LEN(chosen) = 0 THEN chosen = ResolveMusicIn$("assets/music/", b)
    ResolveMusic$ = chosen
END FUNCTION

' Strip a trailing known audio extension from a track name (so "everdark.rad" -> "everdark").
FUNCTION MusicBaseName$ (nm AS STRING)
    DIM exts(1 TO 10) AS STRING, i AS INTEGER, b AS STRING
    exts(1) = ".mid": exts(2) = ".rad": exts(3) = ".s3m": exts(4) = ".mod": exts(5) = ".xm"
    exts(6) = ".it": exts(7) = ".ogg": exts(8) = ".mp3": exts(9) = ".flac": exts(10) = ".wav"
    b = _TRIM$(nm)
    FOR i = 1 TO 10
        IF LEN(b) > LEN(exts(i)) THEN
            IF LCASE$(RIGHT$(b, LEN(exts(i)))) = exts(i) THEN b = LEFT$(b, LEN(b) - LEN(exts(i))): EXIT FOR
        END IF
    NEXT
    MusicBaseName$ = b
END FUNCTION

' Highest-quality file for bpath name b within one directory (worst->best ladder), "" if none.
FUNCTION ResolveMusicIn$ (dir AS STRING, b AS STRING)
    DIM exts(1 TO 10) AS STRING, i AS INTEGER, chosen AS STRING, p AS STRING
    exts(1) = ".mid": exts(2) = ".rad": exts(3) = ".s3m": exts(4) = ".mod": exts(5) = ".xm"
    exts(6) = ".it": exts(7) = ".ogg": exts(8) = ".mp3": exts(9) = ".flac": exts(10) = ".wav"
    chosen = ""
    FOR i = 1 TO 10
        p = dir + b + exts(i)
        IF _FILEEXISTS(p) THEN chosen = p
    NEXT
    ResolveMusicIn$ = chosen
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

' Load the sound file for effect nm into the SFX map (silent if none exists). Honours the
' selected SFX PACK: try assets/sfx/<pack>/<nm>.<ext> first, then fall back to the flat
' assets/sfx/<nm>.<ext> -- so a partial pack overrides only the effects it actually ships.
SUB RegisterSfx (nm AS STRING)
    DIM h AS LONG
    h = 0
    IF LEN(opt_sfxpack) > 0 THEN h = OpenSfx&("assets/sfx/" + opt_sfxpack + "/" + nm)
    IF h <= 0 THEN h = OpenSfx&("assets/sfx/" + nm)
    IF h > 0 THEN
        IF SFX_N < UBOUND(SFX_NAME) THEN SFX_N = SFX_N + 1: SFX_NAME(SFX_N) = nm: SFX_HND(SFX_N) = h
    END IF
END SUB

' Open the first existing <bpath>.<ext> (ogg/mp3/wav/flac) -> handle, or 0 if none exist.
FUNCTION OpenSfx& (bpath AS STRING)
    DIM h AS LONG
    h = 0
    IF _FILEEXISTS(bpath + ".ogg") THEN h = _SNDOPEN(bpath + ".ogg")
    IF h <= 0 THEN IF _FILEEXISTS(bpath + ".mp3") THEN h = _SNDOPEN(bpath + ".mp3")
    IF h <= 0 THEN IF _FILEEXISTS(bpath + ".wav") THEN h = _SNDOPEN(bpath + ".wav")
    IF h <= 0 THEN IF _FILEEXISTS(bpath + ".flac") THEN h = _SNDOPEN(bpath + ".flac")
    OpenSfx& = h
END FUNCTION

' Release every loaded SFX file and empty the map (before reloading on a pack change).
SUB FreeSfxFiles
    DIM i AS INTEGER
    FOR i = 1 TO SFX_N
        IF SFX_HND(i) > 0 THEN _SNDCLOSE SFX_HND(i)
        SFX_HND(i) = 0: SFX_NAME(i) = ""
    NEXT i
    SFX_N = 0
END SUB

' Reload the SFX map from the currently selected pack (call after opt_sfxpack changes).
SUB ReloadSfxPack
    FreeSfxFiles
    InitSfxFiles
END SUB

' Handle of the loaded file for Sfx name nm, or 0 if none (caller then beeps).
FUNCTION SfxHandle& (nm AS STRING)
    DIM i AS INTEGER
    SfxHandle = 0
    FOR i = 1 TO SFX_N
        IF SFX_NAME(i) = nm THEN SfxHandle = SFX_HND(i): EXIT FUNCTION
    NEXT i
END FUNCTION


' ----------------------------------------------------------------------------
'  AUDIO PACKS -- a subdir under assets/sfx/ or assets/music/ is a "theme". The
'  SETTINGS SFX Pack / Music Pack rows cycle through the packs found on disk; if
'  there are no subdirs the flat main dir is all there is (index 0 = "(main)").
' ----------------------------------------------------------------------------

' TRUE if a filename ends in a known audio extension.
FUNCTION IsAudioExt% (nm AS STRING)
    DIM p AS INTEGER, ex AS STRING
    IsAudioExt = 0
    p = _INSTRREV(nm, ".")
    IF p = 0 THEN EXIT FUNCTION
    ex = LCASE$(MID$(nm, p))
    SELECT CASE ex
        CASE ".ogg", ".mp3", ".wav", ".flac", ".mid", ".rad", ".mod", ".s3m", ".xm", ".it": IsAudioExt = -1
    END SELECT
END FUNCTION

' TRUE if directory dir (a "<path>/") holds at least one audio file at its top level.
FUNCTION DirHasAudio% (dir AS STRING)
    DIM e AS STRING
    DirHasAudio = 0
    e = _FILES$(dir)
    DO WHILE LEN(e) > 0
        IF RIGHT$(e, 1) <> "/" THEN IF IsAudioExt%(e) THEN DirHasAudio = -1: EXIT FUNCTION
        e = _FILES$
    LOOP
END FUNCTION

' Fill packs() with the pack subdirs under bpath (each holding >=1 audio file). packs(0) = ""
' ("(main)" = the flat dir); packs(1..cnt) = subdir names. Two passes so the nested _FILES$
' scan in DirHasAudio never clobbers the outer (single-cursor) directory enumeration.
SUB ScanAudioPacks (bpath AS STRING, packs() AS STRING, cnt AS INTEGER)
    DIM e AS STRING, nm AS STRING, subs(1 TO 64) AS STRING, ns AS INTEGER, i AS INTEGER
    packs(0) = "": cnt = 0
    IF NOT _DIREXISTS(bpath) THEN EXIT SUB
    e = _FILES$(bpath)                                    ' pass 1: collect subdir names
    DO WHILE LEN(e) > 0
        IF RIGHT$(e, 1) = "/" THEN
            nm = LEFT$(e, LEN(e) - 1)
            IF nm <> "." AND nm <> ".." AND ns < 64 THEN ns = ns + 1: subs(ns) = nm
        END IF
        e = _FILES$
    LOOP
    FOR i = 1 TO ns                                       ' pass 2: keep the ones with audio
        IF DirHasAudio%(bpath + subs(i) + "/") THEN
            IF cnt < UBOUND(packs) THEN cnt = cnt + 1: packs(cnt) = subs(i)
        END IF
    NEXT i
END SUB

' (Re)scan both pack lists into the SFXPACKS/MUSICPACKS globals. Called at startup and each
' time SETTINGS opens, so packs added on disk show up without a rebuild.
SUB ScanAllPacks
    ScanAudioPacks "assets/sfx/", SFXPACKS(), SFXPACK_N
    ScanAudioPacks "assets/music/", MUSICPACKS(), MUSICPACK_N
    ' a saved pack whose folder has since vanished falls back to the main dir
    IF LEN(opt_sfxpack) > 0 AND PackIndex%(SFXPACKS(), SFXPACK_N, opt_sfxpack) = 0 THEN opt_sfxpack = ""
    IF LEN(opt_musicpack) > 0 AND PackIndex%(MUSICPACKS(), MUSICPACK_N, opt_musicpack) = 0 THEN opt_musicpack = ""
END SUB

' Index of name within packs(0..cnt), or 0 (the main dir) if not present.
FUNCTION PackIndex% (packs() AS STRING, cnt AS INTEGER, want AS STRING)
    DIM i AS INTEGER
    PackIndex = 0
    FOR i = 1 TO cnt
        IF packs(i) = want THEN PackIndex = i: EXIT FUNCTION
    NEXT i
END FUNCTION

' A pack name for display: "(main)" for the flat dir, else the subdir name.
FUNCTION PackLabel$ (want AS STRING)
    IF LEN(want) = 0 THEN PackLabel$ = "(main)" ELSE PackLabel$ = want
END FUNCTION

' Cycle the SFX pack by delta and reload the effect files from the new pack.
SUB CycleSfxPack (delta AS INTEGER)
    DIM idx AS INTEGER
    idx = PackIndex%(SFXPACKS(), SFXPACK_N, opt_sfxpack) + delta
    IF idx < 0 THEN idx = SFXPACK_N
    IF idx > SFXPACK_N THEN idx = 0
    opt_sfxpack = SFXPACKS(idx)
    ReloadSfxPack
    Sfx "select"                                         ' preview a cue from the new pack
END SUB

' Cycle the MUSIC pack by delta; re-resolve the current track so it switches immediately.
SUB CycleMusicPack (delta AS INTEGER)
    DIM idx AS INTEGER
    idx = PackIndex%(MUSICPACKS(), MUSICPACK_N, opt_musicpack) + delta
    IF idx < 0 THEN idx = MUSICPACK_N
    IF idx > MUSICPACK_N THEN idx = 0
    opt_musicpack = MUSICPACKS(idx)
    music_curfile = ""                                   ' force PlayLevelMusic to re-resolve
    IF music_level >= 1 AND music_level <= 9 THEN PlayLevelMusic music_level
    Sfx "select"
END SUB

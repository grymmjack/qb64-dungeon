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
    DIM i AS INTEGER, lv AS INTEGER, pl AS STRING
    FOR i = 1 TO 9: MUSIC_FILE(i) = "": NEXT i
    music_level = 0: music_curfile = ""
    ' a selected MUSIC PACK may ship its OWN playlist.txt (its own per-level track names);
    ' otherwise use the flat assets/music/playlist.txt.
    pl = "assets/music/playlist.txt"
    IF LEN(opt_musicpack) > 0 THEN
        IF _FILEEXISTS("assets/music/" + opt_musicpack + "/playlist.txt") THEN pl = "assets/music/" + opt_musicpack + "/playlist.txt"
    END IF
    ReadDataFile pl
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
    ' the entry changed: crossfade from the current track to the best file for the new name
    music_curfile = fn                              ' remember the ENTRY so we don't re-resolve every step
    path = ResolveMusic$(fn)                        ' bare name -> best-quality file on disk ("" = none)
    BeginTrack path, -1                             ' crossfade in over ~MUSIC_FADE_SEC ("" -> fades the old out to silence)
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
    IF music_fadeout > 0 THEN _SNDSTOP music_fadeout: _SNDCLOSE music_fadeout
    music_handle = 0: music_fadeout = 0: music_fading = 0
    music_level = 0: music_curfile = ""
END SUB

' Crossfade helper: bring `path` in as the new music while whatever's playing fades OUT.
' If nothing is playing yet, the new track just starts at full volume (no crossfade to do).
' Any crossfade already in progress is snapped off first, so at most two tracks overlap.
' The ramp itself is advanced by AudioTick (called each frame) over MUSIC_FADE_SEC seconds;
' this SUB only sets it up and returns immediately, so the game never blocks on a transition.
SUB BeginTrack (path AS STRING, doloop AS INTEGER)
    IF music_fadeout > 0 THEN _SNDSTOP music_fadeout: _SNDCLOSE music_fadeout   ' retire the last fade-out track
    music_fadeout = music_handle                    ' the current track (if any) becomes the fade-OUT track
    music_handle = 0
    IF LEN(path) > 0 THEN
        music_handle = _SNDOPEN(path)
        IF music_handle > 0 THEN
            _SNDVOL music_handle, 0                  ' ALWAYS start silent -> AudioTick rings it up over MUSIC_FADE_SEC:
            IF doloop THEN _SNDLOOP music_handle ELSE _SNDPLAY music_handle   ' a crossfade if a track fades out under it, else a plain fade-in from silence
        END IF
    END IF
    music_fade_start = TIMER                         ' the music channel ALWAYS arrives by fading (never a hard cut-in)
    music_fading = -1
END SUB

' Per-frame audio ramp: advances the music crossfade AND the narration in/out envelope.
' Call once per frame from every loop that runs while audio may be playing (the play loop,
' the menu, combat, the reference screens, and the key-wait helpers). It is TIME-based
' (TIMER - start), so irregular ticking never leaves a fade stuck -- it lands at the right
' level by wall-clock the moment any loop calls it.
SUB AudioTick
    DIM tv AS SINGLE, el AS DOUBLE, frac AS SINGLE
    DIM npos AS DOUBLE, g AS SINGLE, g2 AS SINGLE
    ' --- music crossfade ---
    IF music_fading THEN
        tv = opt_musicvol / 10
        el = TIMER - music_fade_start
        IF el < 0 THEN el = el + 86400#                 ' TIMER wraps at midnight
        frac = el / MUSIC_FADE_SEC
        IF frac >= 1 THEN                               ' fade complete: drop the old track, new to full
            IF music_fadeout > 0 THEN _SNDSTOP music_fadeout: _SNDCLOSE music_fadeout
            music_fadeout = 0
            IF music_handle > 0 THEN _SNDVOL music_handle, tv
            music_fading = 0
        ELSE                                            ' mid-fade: new rises, old falls, they cross
            IF music_handle > 0 THEN _SNDVOL music_handle, tv * frac
            IF music_fadeout > 0 THEN _SNDVOL music_fadeout, tv * (1 - frac)
        END IF
    END IF
    ' --- narration fade in/out (attenuates the record-click at both ends of a spoken line) ---
    ' WALL-CLOCK envelope: _SNDGETPOS reports 0 until the buffer starts, so a playhead-based
    ' ramp stayed silent then snapped in. Timing off narr_start (set at _SNDPLAY) ramps smoothly.
    IF narr_handle > 0 THEN
        npos = TIMER - narr_start                       ' seconds since this line began (npos reused as elapsed)
        IF npos < 0 THEN npos = npos + 86400#            ' TIMER midnight wrap
        g = 1
        IF narr_fadein > 0 THEN IF npos < narr_fadein THEN g = npos / narr_fadein
        IF narr_fadeout > 0 AND narr_len > 0 THEN         ' both pure reads -> AND is safe here
            IF npos > narr_len - narr_fadeout THEN
                g2 = (narr_len - npos) / narr_fadeout
                IF g2 < g THEN g = g2                   ' the tighter of in/out wins on a short clip
            END IF
        END IF
        IF g < 0 THEN g = 0
        IF g > 1 THEN g = 1
        IF g > 0 AND g < 1 THEN g = g ^ narr_curve   ' SHAPE the ramp (linear sounds abrupt on speech): <1 sharp, >1 gentle
        _SNDVOL narr_handle, (opt_voicevol / 10) * g
    END IF
END SUB

' Load the narration fade envelope for the CURRENT pack from its pack.conf (FADEIN=/FADEOUT=
' seconds -- a CREATOR setting, not a player one). Defaults NARR_FADE_IN/OUT_DEF when the file
' or a key is absent. Cached by pack name so it only re-reads on a pack change.
SUB LoadNarrConf
    DIM cf AS STRING, raw AS STRING
    narr_conf_pack = opt_narrationpack
    narr_conf_loaded = -1
    narr_fadein = NARR_FADE_IN_DEF
    narr_fadeout = NARR_FADE_OUT_DEF
    narr_curve = NARR_FADE_CURVE_DEF
    IF LEN(opt_narrationpack) > 0 THEN cf = "assets/narration/" + opt_narrationpack + "/pack.conf" ELSE cf = "assets/narration/pack.conf"
    IF NOT _FILEEXISTS(cf) THEN EXIT SUB
    raw = UCASE$(_READFILE$(cf))
    narr_fadein = ConfNum(raw, "FADEIN", NARR_FADE_IN_DEF)
    narr_fadeout = ConfNum(raw, "FADEOUT", NARR_FADE_OUT_DEF)
    narr_curve = ConfNum(raw, "FADECURVE", NARR_FADE_CURVE_DEF)
    IF narr_curve < .05 THEN narr_curve = .05       ' clamp to a sane exponent range (avoid 0/negative powers)
    IF narr_curve > 8 THEN narr_curve = 8
END SUB

' Read `<kname>=<number>` (seconds) out of a pack.conf blob; returns dflt if absent.
FUNCTION ConfNum (raw AS STRING, kname AS STRING, dflt AS SINGLE)
    DIM p AS INTEGER, e AS INTEGER, c AS STRING, s AS STRING
    ConfNum = dflt
    p = INSTR(raw, kname + "=")
    IF p = 0 THEN EXIT FUNCTION
    p = p + LEN(kname) + 1
    e = p
    DO WHILE e <= LEN(raw)
        c = MID$(raw, e, 1)
        IF c = CHR$(10) OR c = CHR$(13) THEN EXIT DO
        e = e + 1
    LOOP
    s = _TRIM$(MID$(raw, p, e - p))
    IF LEN(s) > 0 THEN ConfNum = VAL(s)
END FUNCTION


' ----------------------------------------------------------------------------
'  Optional file-based sound effects. Drop assets/sfx/<name>.ogg (or .mp3/.wav/
'  .flac) next to a beeper effect and it plays that file instead; any effect with
'  no file keeps its built-in tone. <name> is the Sfx name: move, bump, hit, crit,
'  treasure, chest, boom, ... (see the SELECT CASE in Sfx). Preloaded once here;
'  Sfx plays copies so rapid effects overlap. Honors the SFX Vol slider.
' ----------------------------------------------------------------------------
SUB InitSfxFiles
    DIM lst AS STRING, i AS INTEGER, p AS INTEGER, nm AS STRING
    SFX_N = 0
    lst = SfxNameList$ + " ": p = 1                     ' one source of truth (also dumped by `audiomanifest`)
    FOR i = 1 TO LEN(lst)
        IF MID$(lst, i, 1) = " " THEN
            nm = _TRIM$(MID$(lst, p, i - p))
            IF LEN(nm) > 0 THEN RegisterSfx nm
            p = i + 1
        END IF
    NEXT i
END SUB

' The full roster of themeable effect names, space-separated. InitSfxFiles registers each
' (loads a file if one exists, else the beeper covers it); `audiomanifest` dumps them.
FUNCTION SfxNameList$
    SfxNameList$ = "move bump door strongdoor breakdoor secret secretpass key idle treasure trap hit miss crit fumble search win lose saveok savebad chest boom hiss fizzle alarm select levelup voice diceroll diceland dice_edge dice_settle dice-math-1 dice-math-2 monster-pain player-pain death monster-death maxhit heartbeat curio poison-proc frost-proc teleport fireball lightning-bolt"
END FUNCTION

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
    ScanAudioPacks "assets/narration/", NARRPACKS(), NARRPACK_N
    ScanArtPacks                                          ' pixel-art theme packs (subdirs of assets/pixel-art/)
    ' a saved pack whose folder has since vanished falls back to the main dir
    IF LEN(opt_sfxpack) > 0 AND PackIndex%(SFXPACKS(), SFXPACK_N, opt_sfxpack) = 0 THEN opt_sfxpack = ""
    IF LEN(opt_musicpack) > 0 AND PackIndex%(MUSICPACKS(), MUSICPACK_N, opt_musicpack) = 0 THEN opt_musicpack = ""
    IF LEN(opt_narrationpack) > 0 AND PackIndex%(NARRPACKS(), NARRPACK_N, opt_narrationpack) = 0 THEN opt_narrationpack = ""
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
    LoadPlaylist                                         ' the new pack may bring its own playlist.txt
    music_curfile = ""                                   ' force PlayLevelMusic to re-resolve
    IF music_level >= 1 AND music_level <= 9 THEN PlayLevelMusic music_level
    Sfx "select"
END SUB


' ----------------------------------------------------------------------------
'  NARRATION -- spoken-word audio for a strings.txt key. A file named after the
'  key (assets/narration/[pack]/<key>.ogg|mp3|wav|flac) plays when that line is
'  shown; absent -> silent (the typewriter voice blips still cover it). Load-on-
'  demand + one line at a time, so hundreds of lines cost no startup memory.
' ----------------------------------------------------------------------------

' Path of the first existing <base>.<ext> (ogg/mp3/wav/flac), or "" if none.
FUNCTION FirstAudioFile$ (bpath AS STRING)
    IF _FILEEXISTS(bpath + ".ogg") THEN FirstAudioFile$ = bpath + ".ogg": EXIT FUNCTION
    IF _FILEEXISTS(bpath + ".mp3") THEN FirstAudioFile$ = bpath + ".mp3": EXIT FUNCTION
    IF _FILEEXISTS(bpath + ".wav") THEN FirstAudioFile$ = bpath + ".wav": EXIT FUNCTION
    IF _FILEEXISTS(bpath + ".flac") THEN FirstAudioFile$ = bpath + ".flac": EXIT FUNCTION
    FirstAudioFile$ = ""
END FUNCTION

' Narration file for a string key: selected pack first, then the flat dir. "" if none.
FUNCTION NarratePath$ (nkey AS STRING)
    DIM p AS STRING
    NarratePath$ = ""
    IF LEN(opt_narrationpack) > 0 THEN
        p = FirstAudioFile$("assets/narration/" + opt_narrationpack + "/" + nkey)
        IF LEN(p) > 0 THEN NarratePath$ = p: EXIT FUNCTION
    END IF
    NarratePath$ = FirstAudioFile$("assets/narration/" + nkey)
END FUNCTION

' Stop and release the current narration line.
SUB NarrateStop
    IF narr_handle > 0 THEN _SNDSTOP narr_handle: _SNDCLOSE narr_handle: narr_handle = 0
END SUB

' Speak the narration line for a string key (interrupts any line already speaking).
' No-op if narration is off or no file exists for the key. Volume follows Voice Vol.
SUB Narrate (nkey AS STRING)
    DIM p AS STRING
    IF NOT opt_narration THEN EXIT SUB
    ' POLITENESS: never cut off a line that's still speaking -- let it finish and skip the
    ' new one. (The ambient text-crawl voice keeps playing after its typewriter ends, and
    ' combat lines fire in quick succession -- without this they chop each other off.)
    IF narr_handle > 0 THEN IF _SNDPLAYING(narr_handle) THEN EXIT SUB
    p = NarratePath$(nkey)
    IF LEN(p) = 0 THEN EXIT SUB
    ' refresh the fade envelope if the pack changed (or on the very first line)
    IF (NOT narr_conf_loaded) OR (narr_conf_pack <> opt_narrationpack) THEN LoadNarrConf
    NarrateStop                                     ' release the finished handle before the next line
    narr_handle = _SNDOPEN(p)
    IF narr_handle > 0 THEN
        ' start SILENT when a fade-in is set so AudioTick can ramp it up from 0 (masking the
        ' record-click). The envelope is WALL-CLOCK (narr_start/narr_len), NOT the playhead --
        ' _SNDGETPOS reads 0 until the buffer actually starts, which made the fade snap in.
        IF narr_fadein > 0 THEN _SNDVOL narr_handle, 0 ELSE _SNDVOL narr_handle, opt_voicevol / 10
        _SNDPLAY narr_handle
        narr_start = TIMER
        narr_len = _SNDLEN(narr_handle)             ' read once; 0 if the format doesn't report length (-> no fade-out)
    END IF
END SUB

' Tiered narration: speak `nkey` only if the SETTINGS narration frequency reaches
' this tier. NARR_FLAVOR (0) rooms/chambers/ambient/win-lose is the base and can use
' bare Narrate; NARR_EVENT (1) = curios/traps; NARR_COMBAT (2) = combat. Graceful --
' still silent if narration is off or no voice file exists for the key.
SUB NarrateT (nkey AS STRING, tier AS INTEGER)
    IF opt_narrfreq >= tier THEN Narrate nkey
END SUB

' TRUE if narration is on AND a voice file exists for this key -- callers use it to decide
' whether to Narrate + mute the per-glyph blips (the spoken line covers the text crawl).
FUNCTION HasNarration% (nkey AS STRING)
    HasNarration = 0
    IF NOT opt_narration THEN EXIT FUNCTION
    IF LEN(nkey) = 0 THEN EXIT FUNCTION
    IF LEN(NarratePath$(nkey)) > 0 THEN HasNarration = -1
END FUNCTION

' Filesystem-safe narration slug: lowercase, [a-z0-9] kept, every other run -> one "-".
' "KING'S LIBRARY" -> "kings-library", "THE CRYPT" -> "the-crypt". Used to key narration
' files after room / chamber / curio names (e.g. Narrate "chamber." + NarrSlug$(name)).
FUNCTION NarrSlug$ (s AS STRING)
    DIM i AS INTEGER, c AS STRING, r AS STRING, dash AS INTEGER
    FOR i = 1 TO LEN(s)
        c = LCASE$(MID$(s, i, 1))
        IF (c >= "a" AND c <= "z") OR (c >= "0" AND c <= "9") THEN
            r = r + c: dash = 0
        ELSEIF c = "'" THEN
            ' drop apostrophes so KING'S -> kings (no stray dash)
        ELSEIF LEN(r) > 0 AND NOT dash THEN
            r = r + "-": dash = -1
        END IF
    NEXT i
    IF LEN(r) > 0 THEN IF RIGHT$(r, 1) = "-" THEN r = LEFT$(r, LEN(r) - 1)
    NarrSlug$ = r
END FUNCTION

' Cycle the narration setting: OFF -> (main) -> pack1 .. packN -> OFF. One SETTINGS row
' does both the on/off and the pack pick. Reloads nothing (narration is load-on-demand).
SUB CycleNarration (delta AS INTEGER)
    DIM idx AS INTEGER
    ' virtual index: 0 = OFF, 1 = (main), 2..N+1 = packs
    IF NOT opt_narration THEN idx = 0 ELSE idx = 1 + PackIndex%(NARRPACKS(), NARRPACK_N, opt_narrationpack)
    idx = idx + delta
    IF idx < 0 THEN idx = NARRPACK_N + 1
    IF idx > NARRPACK_N + 1 THEN idx = 0
    IF idx = 0 THEN
        opt_narration = FALSE: NarrateStop
    ELSE
        opt_narration = -1: opt_narrationpack = NARRPACKS(idx - 1)
    END IF
    Sfx "select"
END SUB

' Display label for the narration row: "off", or the pack name / "(main)".
FUNCTION NarrationLabel$
    IF NOT opt_narration THEN NarrationLabel$ = "off" ELSE NarrationLabel$ = PackLabel$(opt_narrationpack)
END FUNCTION

' SETTINGS label for the narration-frequency tier (which spoken tiers are on).
FUNCTION NarrFreqLabel$
    SELECT CASE opt_narrfreq
        CASE NARR_FLAVOR: NarrFreqLabel$ = "Flavor"
        CASE NARR_EVENT: NarrFreqLabel$ = "Flavor + Events"
        CASE ELSE: NarrFreqLabel$ = "Flavor + Events + Combat"
    END SELECT
END FUNCTION


' ----------------------------------------------------------------------------
'  MUSIC CUES -- non-level tracks: victory / lose (one-shots) and combat-low /
'  combat-high / combat-intense (looped). A cue temporarily overrides the level
'  music; EndCue restores it. If the cue file doesn't exist the level music is
'  left playing (never cut to silence), so cues are safe to wire before soundmon
'  has generated them.
' ----------------------------------------------------------------------------

' Play a named music cue. doloop = loop it (combat) vs one-shot (victory/lose).
' No-op (keeps the level track) when music is off or no file exists for the name.
SUB PlayCue (nm AS STRING, doloop AS INTEGER)
    DIM path AS STRING
    IF NOT opt_music THEN EXIT SUB
    path = ResolveMusic$(nm)                             ' pack-aware, best-quality file ("" = none)
    IF LEN(path) = 0 THEN EXIT SUB                       ' no cue on disk -> leave the level music alone
    music_curfile = ""                                   ' so EndCue's PlayLevelMusic re-resolves the level track
    music_cue_active = -1
    BeginTrack path, doloop                              ' crossfade to the cue (level track fades under it)
END SUB

' End a screen/combat cue and return to the BACKGROUND track: the level track when
' inside a delve (music_level 1-9), else the MENU theme (music_level 0). No-op if no
' cue is active.
SUB EndCue
    IF NOT music_cue_active THEN EXIT SUB
    music_cue_active = FALSE
    music_curfile = ""                              ' force a re-resolve; PlayLevelMusic/PlayMenuMusic crossfade FROM the cue
    IF music_level >= 1 AND music_level <= 9 THEN PlayLevelMusic music_level ELSE PlayMenuMusic
END SUB

' Play the MAIN MENU theme (everdark) as the background track, and mark the context
' as "not in a delve" (music_level = 0) so EndCue restores THIS when a screen cue ends.
' Won't restart everdark if it's already the track playing. Graceful: silent if music
' is off or no everdark file exists. Centralises what RunMenu used to do inline, so the
' menu screens (settings / char-gen / lords) can override it with a cue and get it back.
SUB PlayMenuMusic
    DIM path AS STRING
    music_level = 0                                 ' menu context (not a dungeon level)
    IF NOT opt_music THEN EXIT SUB
    IF music_handle > 0 AND music_curfile = "everdark" THEN EXIT SUB   ' already playing -> no restart
    music_curfile = "everdark"
    path = ResolveMusic$("everdark")
    BeginTrack path, -1                             ' crossfade the menu theme in (fades a screen cue out under it)
END SUB

' Which combat cue fits the fight: intense for a boss, high for the deep levels, else low.
FUNCTION CombatCueName$ (lvl AS INTEGER, isboss AS INTEGER)
    IF isboss THEN
        CombatCueName$ = "combat-intense"
    ELSEIF lvl >= 6 THEN
        CombatCueName$ = "combat-high"
    ELSE
        CombatCueName$ = "combat-low"
    END IF
END FUNCTION

' Look up want in the parallel keys()/vals() arrays (case-insensitive), or a placeholder.
FUNCTION LookupDesc$ (dkey() AS STRING, dval() AS STRING, dn AS INTEGER, want AS STRING)
    DIM i AS INTEGER
    LookupDesc$ = "(no description -- add one)"
    FOR i = 1 TO dn
        IF dkey(i) = UCASE$(want) THEN LookupDesc$ = dval(i): EXIT FUNCTION
    NEXT i
END FUNCTION

' `dungeon.run audiomanifest` -- print EVERY audio asset as  path | description-or-text  so the
' AI generators self-serve: SFX/MUSIC get their generation PROMPT (from assets/{sfx,music}/
' descriptions.txt), NARRATION gets the LINE TO SPEAK (from the loaded flavor/data, always in
' sync with what the game shows). Path is under assets/, sans .ogg/.mp3/.wav/.flac; a pack
' subfolder overrides. regular/chamber/curio lines are the exact on-screen text; room lines are a
' representative sample; intro/titles are clean spoken versions.
SUB DumpAudioManifest
    DIM i AS INTEGER, lvl AS INTEGER, si AS INTEGER, lst AS STRING, p AS INTEGER, nm AS STRING, seen AS STRING
    DIM dkey(1 TO 300) AS STRING, dval(1 TO 300) AS STRING, dn AS INTEGER
    _DEST _CONSOLE
    PRINT "# DUNGEON! audio manifest  -- feed to the generators. path is under assets/ , add"
    PRINT "# .ogg/.mp3/.wav/.flac ; a pack subfolder overrides. sfx/music: path | length | prompt"
    PRINT "# (length is a TARGET/MAX -- keep sfx at or under it); narration: path | line to speak."
    PRINT

    PRINT "# --- SFX (assets/sfx/[pack]/) : path | max-seconds | generation prompt ---"
    dn = 0: ReadDataFile "assets/sfx/descriptions.txt"
    FOR i = 1 TO DLINE_N
        IF dn < 300 THEN dn = dn + 1: dkey(dn) = UCASE$(_TRIM$(DField$(DLINE(i), 1))): dval(dn) = _TRIM$(DField$(DLINE(i), 2)) + " | " + _TRIM$(DField$(DLINE(i), 3))
    NEXT i
    lst = SfxNameList$ + " ": p = 1
    FOR i = 1 TO LEN(lst)
        IF MID$(lst, i, 1) = " " THEN
            nm = _TRIM$(MID$(lst, p, i - p)): p = i + 1
            IF LEN(nm) > 0 THEN PRINT "sfx/" + nm + " | " + LookupDesc$(dkey(), dval(), dn, nm)
        END IF
    NEXT i
    PRINT

    PRINT "# --- MUSIC (assets/music/[pack]/) : path | length | generation prompt ---"
    dn = 0: ReadDataFile "assets/music/descriptions.txt"
    FOR i = 1 TO DLINE_N
        IF dn < 300 THEN dn = dn + 1: dkey(dn) = UCASE$(_TRIM$(DField$(DLINE(i), 1))): dval(dn) = _TRIM$(DField$(DLINE(i), 2)) + " | " + _TRIM$(DField$(DLINE(i), 3))
    NEXT i
    seen = " "
    FOR lvl = 1 TO 9                                    ' per-level tracks (unique bare names from playlist)
        nm = _TRIM$(MUSIC_FILE(lvl))
        IF LEN(nm) > 0 AND INSTR(seen, " " + nm + " ") = 0 THEN PRINT "music/" + nm + " | " + LookupDesc$(dkey(), dval(), dn, nm): seen = seen + nm + " "
    NEXT lvl
    lst = "vr-theme introsplash everdark victory lose combat-low combat-high combat-intense settings chargen treasury bestiary curio lords gamemenu ": p = 1
    FOR i = 1 TO LEN(lst)                               ' fixed intro/menu/cue tracks (deduped vs level names)
        IF MID$(lst, i, 1) = " " THEN
            nm = _TRIM$(MID$(lst, p, i - p)): p = i + 1
            IF LEN(nm) > 0 AND INSTR(seen, " " + nm + " ") = 0 THEN PRINT "music/" + nm + " | " + LookupDesc$(dkey(), dval(), dn, nm): seen = seen + nm + " "
        END IF
    NEXT i
    PRINT

    PRINT "# --- NARRATION (assets/narration/[pack]/) : path | line to speak ---"
    PRINT "narration/intro.descent | Torchlight gutters as you cross the threshold into the ancient dungeon. Nine levels coil below, each darker and deadlier than the last. Somewhere in the depths lies the Level Key -- claim it, gather a fortune in gold, and return alive to this entrance. Few ever escape. Let the delving begin."
    PRINT "narration/win.title | Victory."
    PRINT "narration/win.subtitle | " + _TRIM$(Say$("win.subtitle"))
    PRINT "narration/lose.title | You died."
    PRINT "narration/lose.subtitle | " + _TRIM$(Say$("lose.subtitle"))
    FOR lvl = 1 TO 9                                    ' ambient one-liners: exact per-line text
        FOR i = 1 TO REG_N(lvl)
            PRINT "narration/regular." + LTRIM$(STR$(lvl)) + "." + LTRIM$(STR$(i)) + " | " + _TRIM$(REG_FLAV(lvl, i))
        NEXT i
    NEXT lvl
    FOR si = 1 TO SP_N                                  ' named rooms (representative line)
        IF SP_FN(si) > 0 THEN PRINT "narration/room." + NarrSlug$(_TRIM$(SP_KEY(si))) + " | " + _TRIM$(SP_FLAV(si, 1))
    NEXT si
    FOR i = 1 TO CHM_FLAV_N: PRINT "narration/chamber." + NarrSlug$(_TRIM$(CHM_FLAV_NAME(i))) + " | " + _TRIM$(CHM_FLAV_TXT(i)): NEXT i
    FOR i = 1 TO NCURIO: PRINT "narration/curio." + _TRIM$(CURIOS(i).kind) + " | " + _TRIM$(CURIOS(i).prompt): NEXT i
    ' combat narration -- generic per-event voiced lines (Combat tier; see NarrateT / game/COMBAT.bas).
    ' Keep them short and atmospheric; they play OVER the combat banners, so they set mood, not detail.
    PRINT "narration/combat.encounter | A monstrous shape rears up from the dark, barring your path. Steel yourself."
    PRINT "narration/combat.reface | The creature still stands between you and your goal. You must face it."
    PRINT "narration/combat.slay | Your foe crumples and falls still. The way is clear."
    PRINT "narration/combat.flee | You break away and slip back into the shadows, the fight unfinished."
    PRINT "narration/combat.hurt | Pain sears through you as the blow lands. Blood runs."
    PRINT "narration/combat.downed | Your strength fails you. The world tilts, darkens -- and you fall."
END SUB

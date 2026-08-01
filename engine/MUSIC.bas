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
    pl = "assets/music/default/playlist.txt"             ' the DEFAULT pack's playlist is the base
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
    IF LEN(chosen) = 0 THEN chosen = ResolveMusicIn$("assets/music/default/", b)   ' fall back to the DEFAULT pack
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
    exts(6) = ".it"
    ' Tracker modules always outrank the sampled containers -- they are a different kind of asset,
    ' not a container choice. The four sampled slots follow the player's preference.
    FOR i = 1 TO AUDIOPREF_N: exts(6 + i) = AudioExt$(i): NEXT i
    chosen = ""
    ' EXIT FOR on the FIRST hit -- the array order is a PREFERENCE order (trackers, then
    ' ogg | mp3 | flac | wav). Without the early exit `chosen` was overwritten on every match, so
    ' the LAST extension present won: a stray .wav silently beat a hand-authored .rad tracker
    ' module, and .ogg could never win against anything later in the list.
    FOR i = 1 TO 10
        p = dir + b + exts(i)
        IF _FILEEXISTS(p) THEN chosen = p: EXIT FOR
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
' Queue a narration key to be spoken after whatever is already speaking/queued.
' Silently ignored when narration is off or the pack has no file for the key, so a caller can
' queue a name unconditionally and simply get the generic line on its own.
SUB NarrateQueue (nkey AS STRING)
    IF NOT opt_narration THEN EXIT SUB
    IF LEN(NarratePath$(nkey)) = 0 THEN EXIT SUB
    IF narrq_n >= NARRQ_MAX THEN EXIT SUB
    narrq_n = narrq_n + 1: NARRQ(narrq_n) = nkey
END SUB

' Drop anything queued but not yet spoken -- used when the moment has passed (fleeing a fight,
' leaving a screen) so a stale name does not surface over the next thing that happens.
SUB NarrateQueueClear
    narrq_n = 0: narrq_i = 0
END SUB

' Start the next queued line if nothing is speaking. Called from AudioTick, so the queue
' advances on the same frame tick everything else audio does.
SUB NarrateQueueTick
    IF narrq_i >= narrq_n THEN
        IF narrq_n > 0 THEN narrq_n = 0: narrq_i = 0    ' drained -- reset so the array reuses
        EXIT SUB
    END IF
    IF narr_handle > 0 THEN IF _SNDPLAYING(narr_handle) THEN EXIT SUB
    narrq_i = narrq_i + 1
    Narrate NARRQ(narrq_i)
END SUB


SUB AudioTick
    DIM tv AS SINGLE, el AS DOUBLE, frac AS SINGLE
    DIM npos AS DOUBLE, g AS SINGLE, g2 AS SINGLE
    DIM voicing AS INTEGER, dtarget AS SINGLE
    ' --- MUSIC CHANNEL mixdown: player slider x channel gain x duck x crossfade fraction ---
    ' crossfade fraction (1 when not fading); completing a fade drops the outgoing track
    frac = 1
    IF music_fading THEN
        el = TIMER - music_fade_start
        IF el < 0 THEN el = el + 86400#                 ' TIMER wraps at midnight
        frac = el / MUSIC_FADE_SEC
        IF frac >= 1 THEN
            frac = 1
            IF music_fadeout > 0 THEN _SNDSTOP music_fadeout: _SNDCLOSE music_fadeout
            music_fadeout = 0
            music_fading = 0
        END IF
    END IF
    ' voiceover DUCK: dip music toward 1-opt_duckamt/10 while narration is audibly playing,
    ' ramping down fast (attack) and back up gently (release). Nest the _SNDPLAYING test so it
    ' never runs on a 0 handle (QB64 AND doesn't short-circuit).
    voicing = 0
    IF narr_handle > 0 THEN IF _SNDPLAYING(narr_handle) THEN voicing = -1
    IF voicing THEN dtarget = 1 - opt_duckamt / 10 ELSE dtarget = 1
    IF dtarget < 0 THEN dtarget = 0
    IF music_duck > dtarget THEN
        music_duck = music_duck - DUCK_ATTACK
        IF music_duck < dtarget THEN music_duck = dtarget
    ELSEIF music_duck < dtarget THEN
        music_duck = music_duck + DUCK_RELEASE
        IF music_duck > dtarget THEN music_duck = dtarget
    END IF
    ' apply the mixdown every frame (so the duck + slider changes are live, not just during a fade)
    tv = opt_musicvol / 10 * chgain_music * music_duck
    IF music_handle > 0 THEN _SNDVOL music_handle, tv * frac
    IF music_fadeout > 0 THEN _SNDVOL music_fadeout, tv * (1 - frac)
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
        _SNDVOL narr_handle, (opt_voicevol / 10) * chgain_voice * g   ' VOICE CHANNEL mixdown: slider x channel gain x envelope
    END IF
    NarrateQueueTick                                ' start the next composed clip once this one ends
END SUB

' --- audio MIXER helpers ---------------------------------------------------
' Reset the programmatic mixer to unity gains, music open (call once at startup, BEFORE any
' AudioTick -- otherwise music_duck defaults to 0 and the music channel starts silent).
SUB MixerInit
    chgain_music = 1: chgain_voice = 1: chgain_sfx = 1
    music_duck = 1
END SUB

' Set a channel's programmatic gain (1 = unity) on top of the player's volume slider -- the
' hook for mixing buses live from game code, e.g. ChannelGain CH_MUSIC, .5 to half music.
' (Auto voiceover ducking of the music channel is separate; see AudioTick.)
SUB ChannelGain (chan AS INTEGER, gain AS SINGLE)
    SELECT CASE chan
        CASE CH_MUSIC: chgain_music = gain
        CASE CH_VOICE: chgain_voice = gain
        CASE CH_SFX: chgain_sfx = gain
    END SELECT
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
    ' Same per-file pack->default fallback as every other resolver (ArtFile$ / AnsiFile$ /
    ' RegisterSfx / ResolveMusic$ / NarratePath$ / DataPath$): try the selected pack, and if it
    ' ships no pack.conf, read the DEFAULT pack's. This used to stop at the selected pack and
    ' silently keep the built-in defaults, which made a partial pack behave differently from a
    ' partial pack of every other asset type. Consistent with DataPath$ falling back for
    ' tuning.txt -- a pack overrides only what it actually ships.
    cf = ""
    IF LEN(opt_narrationpack) > 0 THEN
        cf = "assets/narration/" + opt_narrationpack + "/pack.conf"
        IF NOT _FILEEXISTS(cf) THEN cf = ""
    END IF
    IF LEN(cf) = 0 THEN cf = "assets/narration/default/pack.conf"
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
    DIM p AS INTEGER, e AS INTEGER, chx AS STRING, s AS STRING
    ConfNum = dflt
    p = INSTR(raw, kname + "=")
    IF p = 0 THEN EXIT FUNCTION
    p = p + LEN(kname) + 1
    e = p
    DO WHILE e <= LEN(raw)
        chx = MID$(raw, e, 1)
        IF chx = CHR$(10) OR chx = CHR$(13) THEN EXIT DO
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
    lst = Game_SfxNames$ + " ": p = 1                     ' one source of truth (also dumped by `audiomanifest`)
    FOR i = 1 TO LEN(lst)
        IF MID$(lst, i, 1) = " " THEN
            nm = _TRIM$(MID$(lst, p, i - p))
            IF LEN(nm) > 0 THEN RegisterSfx nm
            p = i + 1
        END IF
    NEXT i
END SUB

' (SfxNameList$ -> the Game_SfxNames$() hook in game/MANIFEST.bas: the effect roster is
'  game content. DumpAudioManifest + LookupDesc$ moved there too.)

' Load the sound file for effect nm into the SFX map (silent if none exists). Honours the
' selected SFX PACK: try assets/sfx/<pack>/<nm>.<ext> first, then fall back to the flat
' assets/sfx/<nm>.<ext> -- so a partial pack overrides only the effects it actually ships.
SUB RegisterSfx (nm AS STRING)
    DIM h AS LONG
    h = 0
    IF LEN(opt_sfxpack) > 0 THEN h = OpenSfx&("assets/sfx/" + opt_sfxpack + "/" + nm)
    IF h <= 0 THEN h = OpenSfx&("assets/sfx/default/" + nm)   ' fall back to the DEFAULT pack (was the flat dir)
    IF h > 0 THEN
        IF SFX_N < UBOUND(SFX_NAME) THEN SFX_N = SFX_N + 1: SFX_NAME(SFX_N) = nm: SFX_HND(SFX_N) = h
    END IF
END SUB

' The Nth sampled-audio extension in PREFERENCE order (n = 1..AUDIOPREF_N).
'
' Base order is ogg, mp3, flac, wav. `opt_audiopref` promotes one of them to the front and the
' rest keep their relative order -- so the setting expresses "prefer THIS", not a full ranking
' the player would have to spell out.
'
' All three resolvers (OpenSfx&, FirstAudioFile$, ResolveMusicIn$) go through here, so a pack
' behaves identically whichever kind of asset it ships, and the preference cannot drift between
' sfx, music and narration.
FUNCTION AudioExt$ (n AS INTEGER)
    DIM bas(1 TO 4) AS STRING, ord(1 TO 4) AS STRING, i AS INTEGER, k AS INTEGER, pref AS INTEGER   ' `bas` -- BASE is reserved
    bas(1) = ".ogg": bas(2) = ".mp3": bas(3) = ".flac": bas(4) = ".wav"
    IF n < 1 OR n > AUDIOPREF_N THEN EXIT FUNCTION
    pref = opt_audiopref
    IF pref < 1 OR pref > AUDIOPREF_N THEN AudioExt$ = bas(n): EXIT FUNCTION   ' auto
    ord(1) = bas(pref)
    k = 1
    FOR i = 1 TO 4
        IF i <> pref THEN k = k + 1: ord(k) = bas(i)
    NEXT i
    AudioExt$ = ord(n)
END FUNCTION

' Human-readable name of the current preference, for the SETTINGS row.
FUNCTION AudioPrefName$ (v AS INTEGER)
    SELECT CASE v
        CASE 1: AudioPrefName$ = "OGG first"
        CASE 2: AudioPrefName$ = "MP3 first"
        CASE 3: AudioPrefName$ = "FLAC first"
        CASE 4: AudioPrefName$ = "WAV first"
        CASE ELSE: AudioPrefName$ = "auto (ogg>mp3>flac>wav)"
    END SELECT
END FUNCTION

' Open the first existing <bpath>.<ext> in the player's preferred order -> handle, or 0.
FUNCTION OpenSfx& (bpath AS STRING)
    DIM h AS LONG
    h = 0
    ' PREFERENCE ORDER: ogg, mp3, flac, wav -- lossy-compact first, then lossless, then raw.
    ' _SNDOPEN is miniaudio-backed, so all four decode natively. NOTE the consequence of an order:
    ' if two formats of the same sound both exist, the EARLIER one wins and the other is silently
    ' never played -- so after converting a pack, delete the old files or the switch does nothing.
    DIM ax AS INTEGER, px AS STRING
    FOR ax = 1 TO AUDIOPREF_N
        px = bpath + AudioExt$(ax)
        IF _FILEEXISTS(px) THEN h = _SNDOPEN(px)
        IF h > 0 THEN EXIT FOR
    NEXT ax
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
    cnt = 0                                               ' no "(main)" 0-slot: every subfolder (incl "default") is a pack
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
    ScanAnsiPacks                                         ' ANSI-art packs (subdirs of assets/ansi-art/): board + masks + menu art
    ScanDataPacks                                         ' DATA packs (subdirs of assets/data/): monsters/treasures/tuning/classes/strings + flavor -- a whole game
    ' a saved pack whose folder has since vanished (or a blank pick) falls back to a real pack
    IF PackIndex%(SFXPACKS(), SFXPACK_N, opt_sfxpack) = 0 THEN opt_sfxpack = FallbackPack$(SFXPACKS(), SFXPACK_N)
    IF PackIndex%(MUSICPACKS(), MUSICPACK_N, opt_musicpack) = 0 THEN opt_musicpack = FallbackPack$(MUSICPACKS(), MUSICPACK_N)
    ' narration keeps its OFF state; only re-home a stale pack pick while narration is on
    IF opt_narration AND PackIndex%(NARRPACKS(), NARRPACK_N, opt_narrationpack) = 0 THEN opt_narrationpack = FallbackPack$(NARRPACKS(), NARRPACK_N)
END SUB


' A pack name for display: "(main)" for the flat dir, else the subdir name.
FUNCTION PackLabel$ (want AS STRING)
    IF LEN(want) = 0 THEN PackLabel$ = "(main)" ELSE PackLabel$ = want
END FUNCTION

' A safe pack to fall back to when a saved pick is gone/blank: the "default" pack if it
' exists (art/music have one), else the first real pack in the list (sfx/narration have
' no default folder), else "default" as a last resort. Always yields something playable.
FUNCTION FallbackPack$ (packs() AS STRING, cnt AS INTEGER)
    IF PackIndex%(packs(), cnt, "default") > 0 THEN
        FallbackPack$ = "default"
    ELSEIF cnt >= 1 THEN
        FallbackPack$ = packs(1)
    ELSE
        FallbackPack$ = "default"
    END IF
END FUNCTION

' Cycle the SFX pack by delta and reload the effect files from the new pack.
SUB CycleSfxPack (delta AS INTEGER)
    DIM idx AS INTEGER
    idx = PackIndex%(SFXPACKS(), SFXPACK_N, opt_sfxpack) + delta
    IF idx < 1 THEN idx = SFXPACK_N
    IF idx > SFXPACK_N THEN idx = 1
    opt_sfxpack = SFXPACKS(idx)
    ReloadSfxPack
    Sfx "select"                                         ' preview a cue from the new pack
END SUB

' Cycle the MUSIC pack by delta; re-resolve the current track so it switches immediately.
SUB CycleMusicPack (delta AS INTEGER)
    DIM idx AS INTEGER
    idx = PackIndex%(MUSICPACKS(), MUSICPACK_N, opt_musicpack) + delta
    IF idx < 1 THEN idx = MUSICPACK_N
    IF idx > MUSICPACK_N THEN idx = 1
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
    ' Player-preferred order, shared with OpenSfx& and ResolveMusicIn$ via AudioExt$.
    DIM ax AS INTEGER, px AS STRING
    FOR ax = 1 TO AUDIOPREF_N
        px = bpath + AudioExt$(ax)
        IF _FILEEXISTS(px) THEN FirstAudioFile$ = px: EXIT FUNCTION
    NEXT ax
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
    NarratePath$ = FirstAudioFile$("assets/narration/default/" + nkey)   ' fall back to the DEFAULT pack
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

' Tiered narration that SAYS A NAME FIRST: "GOBLINS." then the generic line. `namekey` is
' queued ahead of `nkey`, so one short recording per monster composes with any line rather
' than needing a recording per (monster x line) pair.
'
' Degrades in the useful direction at every step: no name file -> just the line; no line file
' -> just the name; neither -> silence. So a pack can ship names alone and still gain something.
SUB NarrateNamed (namekey AS STRING, nkey AS STRING, tier AS INTEGER)
    IF opt_narrfreq < tier THEN EXIT SUB
    NarrateQueueClear                               ' this moment supersedes anything still pending
    NarrateQueue namekey
    NarrateQueue nkey
    NarrateQueueTick                                ' start immediately rather than waiting a frame
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
    DIM i AS INTEGER, chx AS STRING, r AS STRING, dash AS INTEGER
    FOR i = 1 TO LEN(s)
        chx = LCASE$(MID$(s, i, 1))
        IF (chx >= "a" AND chx <= "z") OR (chx >= "0" AND chx <= "9") THEN
            r = r + chx: dash = 0
        ELSEIF chx = "'" THEN
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
    ' virtual index: 0 = OFF, 1..N = packs (no "(main)" slot anymore)
    IF NOT opt_narration THEN idx = 0 ELSE idx = PackIndex%(NARRPACKS(), NARRPACK_N, opt_narrationpack)
    idx = idx + delta
    IF idx < 0 THEN idx = NARRPACK_N
    IF idx > NARRPACK_N THEN idx = 0
    IF idx = 0 THEN
        opt_narration = FALSE: NarrateStop
    ELSE
        opt_narration = -1: opt_narrationpack = NARRPACKS(idx)
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


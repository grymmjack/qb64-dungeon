' ============================================================================
'  MUSIC.bas -- per-level in-game music (data-driven)
'
'  assets/music/playlist.txt maps each dungeon level (1-9) to a music file in
'  assets/music/. As you cross into a new level the track switches; levels that
'  share a file don't restart it, and a level with no entry keeps whatever's
'  playing. Edit the playlist (and drop in files) + F5 -- no code change.
'
'  _SNDOPEN reads .rad/.mod/.xm/.s3m/.it (trackers) AND .ogg / .mp3 / .wav / .flac,
'  so any of those work as a track. For music-length audio prefer .ogg or .mp3
'  (a .wav is uncompressed and can be huge). Format: level | filename  ('#' comment).
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
    IF fn = music_curfile THEN EXIT SUB            ' this file is already playing -> nothing to do
    ' the track really changed: stop the old one and start the new
    IF music_handle > 0 THEN _SNDSTOP music_handle: _SNDCLOSE music_handle: music_handle = 0
    music_curfile = ""
    path = "assets/music/" + fn
    IF _FILEEXISTS(path) = 0 THEN EXIT SUB          ' missing file -> silence rather than a crash
    music_handle = _SNDOPEN(path)
    IF music_handle > 0 THEN
        music_curfile = fn
        _SNDVOL music_handle, opt_musicvol / 10
        _SNDLOOP music_handle
    END IF
END SUB

' Stop and release the in-game track (called when a run ends, before the menu music).
SUB StopLevelMusic
    IF music_handle > 0 THEN _SNDSTOP music_handle: _SNDCLOSE music_handle
    music_handle = 0: music_level = 0: music_curfile = ""
END SUB

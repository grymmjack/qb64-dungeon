' ============================================================================
'  game/PACKREG.bas -- DUNGEON!'s answers for the pack browser.
'
'  The browser is engine/PACKBROWSE.bas and enumerates whatever trees the asset
'  registry says are pack-structured. These are the four things only this game
'  can answer: which pack is live, how to make one live, which sprites are worth
'  previewing, and what a pack of a kind ought to ship.
' ============================================================================
FUNCTION Game_PackSelected$ (kind AS STRING)
    SELECT CASE LCASE$(_TRIM$(kind))
        CASE "pixelart": Game_PackSelected$ = opt_artpack
        CASE "ansiart": Game_PackSelected$ = opt_ansipack
        CASE "sfx": Game_PackSelected$ = opt_sfxpack
        CASE "music": Game_PackSelected$ = opt_musicpack
        CASE "narration": Game_PackSelected$ = opt_narrationpack
        CASE "data", "flavor", "cutscenes": Game_PackSelected$ = opt_datapack
    END SELECT
END FUNCTION

'--- Selecting takes effect where that kind takes effect: audio and art reload
'    now, data and ansi art are read once at startup and cannot. Say which,
'    rather than pretending they are the same. ---
SUB Game_PackSelect (kind AS STRING, nm AS STRING)
    DIM k AS STRING
    k = LCASE$(_TRIM$(kind))
    IF LEN(_TRIM$(nm)) = 0 THEN EXIT SUB
    SELECT CASE k
        CASE "pixelart": opt_artpack = nm: PB_MSG = "art pack: " + nm
        CASE "ansiart": opt_ansipack = nm: PB_MSG = "ansi art pack: " + nm + "  (applies on next launch)"
        CASE "sfx": opt_sfxpack = nm: ReloadSfxPack: PB_MSG = "sfx pack: " + nm
        CASE "music": opt_musicpack = nm: PlayLevelMusic PlayerLevel%: PB_MSG = "music pack: " + nm
        CASE "narration": opt_narrationpack = nm: PB_MSG = "narration pack: " + nm
        CASE "data", "flavor", "cutscenes"
            opt_datapack = nm: PB_MSG = "data pack: " + nm + "  (applies on next launch)"
    END SELECT
    SaveSettings
END SUB

'--- Four sprites in categories the eye reads differently. Only the art tree has
'    any; every other kind returns "" and the browser lists files instead. ---
FUNCTION Game_PackSample$ (kind AS STRING, slot AS INTEGER)
    IF LCASE$(_TRIM$(kind)) <> "pixelart" THEN EXIT FUNCTION
    SELECT CASE slot
        CASE 1: Game_PackSample$ = "monsters/humanoids/evil-wizard"
        CASE 2: Game_PackSample$ = "treasures/crown-of-gems"
        CASE 3: Game_PackSample$ = "classes/hero"
        CASE 4: Game_PackSample$ = "items/sword"
    END SELECT
END FUNCTION

FUNCTION Game_PackSampleName$ (kind AS STRING, slot AS INTEGER)
    IF LCASE$(_TRIM$(kind)) <> "pixelart" THEN EXIT FUNCTION
    SELECT CASE slot
        CASE 1: Game_PackSampleName$ = "monster"
        CASE 2: Game_PackSampleName$ = "treasure"
        CASE 3: Game_PackSampleName$ = "class"
        CASE 4: Game_PackSampleName$ = "item"
    END SELECT
END FUNCTION

'--- what a pack of this kind ought to ship. Only SFX has a fixed roster here,
'    so only SFX gets a coverage bar; the rest simply list what they have. ---
FUNCTION Game_PackRoster$ (kind AS STRING)
    IF LCASE$(_TRIM$(kind)) = "sfx" THEN Game_PackRoster$ = Game_SfxNames$
END FUNCTION

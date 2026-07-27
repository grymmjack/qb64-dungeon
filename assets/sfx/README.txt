assets/sfx/ -- optional real sound-effect files
================================================

Drop an audio file here named after a sound effect and the game plays it INSTEAD
of the built-in tone "beeper" for that effect. Any effect without a file keeps its
beeper, so you can replace as few or as many as you like. Re-read at launch (F5).

Naming:  <name>.<ext>       e.g.  hit.ogg   treasure.wav   boom.mp3

Extensions tried, in order:  .ogg  .mp3  .wav  .flac   (the first one found wins).
For short effects any format is fine; .ogg or .wav are typical. Volume follows the
SFX Vol slider in SETTINGS. Effects can overlap (each play is an independent copy).

Effect names you can override (from the Sfx dispatcher):

  move        cursor step               bump        walking into a wall
  door        passing through a door    strongdoor  bumping a reinforced door
  breakdoor   smashing a door open      secret      a secret door is found
  secretpass  passing a secret door     key         seizing the Level Key
  idle        idle / ambient tick       treasure    loot / gold gained
  trap        a trap fires              hit         you land a blow
  miss        an attack misses          crit        a critical hit
  fumble      a botched attack          search      searching for doors
  win         victory fanfare           lose        death / defeat
  saveok      a saving throw succeeds   savebad     a saving throw fails
  chest       a curio chest creaks open boom        a bomb blast
  hiss        poison darts              fizzle      frost bomb
  alarm       magic siren               select      menu selection
  levelup     gaining a level / revival
  diceroll    dice thrown (rattle)      diceland    dice come to rest
  dice_edge   3D-dice bounce clack *    dice_settle 3D-dice final settle *
  voice       text-crawl blip (per glyph; keep it SHORT -- it plays once per
              letter. Falls back to the PC-speaker tone when absent.)

  * dice_edge / dice_settle are for the 3D dice only and have NO beeper fallback
    (silent until you add a file). diceroll / diceland DO beep if absent.

Example: put a punchy "thwack.ogg", rename it to hit.ogg, drop it here, press F5 --
every landed blow now thwacks. Delete it and the beeper returns.

PACKS (themes): a SUB-FOLDER here is a pack -- put a themed set of the same
filenames in assets/sfx/<pack-name>/ and pick it in SETTINGS -> SFX Pack. The
pack overrides only the effects it ships; the rest fall back to this flat folder
(then to the beeper). With no sub-folders you just get this flat folder ("(main)").

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

Example: put a punchy "thwack.ogg", rename it to hit.ogg, drop it here, press F5 --
every landed blow now thwacks. Delete it and the beeper returns.

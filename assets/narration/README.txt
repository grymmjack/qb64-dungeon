assets/narration/ -- optional spoken-word narration
====================================================

Drop a voice file here named after a STRING KEY and the game speaks it when that
line is shown -- e.g. a booming "V I C T O R Y" over the win screen. If a key has
no file, nothing is spoken (the typewriter "voice" blips still cover the text).

Narration is keyed by the same keys as the UI strings, so it is driven entirely
by the data files:  assets/data/strings.txt  (key | text).

Naming:  <string-key>.<ext>       e.g.  win.title.wav   lose.title.ogg

Extensions tried, in order:  .ogg  .mp3  .wav  .flac   (the first one found wins).
Lines are loaded on demand and only one plays at a time (a new line interrupts the
one before it), so a large narration set costs no startup memory. Volume follows
the VOICE VOL slider in SETTINGS; turn narration on/off with the SETTINGS
"Narration" row.

Keys the game speaks (drop a matching <key>.<ext> here and it plays; whenever a text
crawl is narrated, its per-glyph blips fall silent so the voice carries it):

  win.title            the victory banner  ("V I C T O R Y")
  lose.title           the death banner    ("Y O U   D I E D")
  intro.descent        the game-open crawl ("THE DESCENT")
  regular.<lvl>.<n>    an ambient one-liner at the top of the screen -- <lvl> = dungeon
                       level 1-9, <n> = the line's index in assets/flavor/regular.txt
                       (line 1 = regular.1.1, ...). One file per line if you want them all.
  room.<slug>          entering a named/special room -- slug of the room name, e.g.
                       "THE CRYPT" -> room.the-crypt, "KING'S LIBRARY" -> room.kings-library
  chamber.<slug>       entering a big named CHAMBER (first monster only) -- e.g.
                       chamber.armory, chamber.torture-chamber. The shown description
                       lives in assets/flavor/chambers.txt; write the voice to match its mood.
  curio.<kind>         a curio appears -- <kind> is chest / fountain / shrine / gamble /
                       peddler / idol / corpse / mushroom / obelisk / cache / mimic ...

  SLUG rule: lowercase, letters+digits kept, apostrophes dropped, every other run
  becomes one "-" (KING'S LIBRARY -> kings-library). The dynamic wording on screen
  (names, gold) can't be matched word-for-word, so write these as ATMOSPHERIC reads.

TIP: run  `dungeon.run audiomanifest`  for the EXACT, always-current list of every
sfx / music / narration file the engine looks for (computed from the loaded data) --
pipe it to your generators to fill in whatever's missing.

...and any other key in strings.txt becomes speakable the moment you add
`Narrate "<key>"` at its display site (win.subtitle, lose.subtitle, end.return,
press.key, ... are all there waiting). To narrate a NEW line, add the line to
strings.txt, drop a matching <key>.<ext> here, and call Narrate "<key>" where it
shows.

PACKS (voices/themes): a SUB-FOLDER here is a pack -- put a full set of voiced
lines in assets/narration/<voice-name>/ and pick it in SETTINGS -> Narration
(cycles OFF -> (main) -> each pack). The pack wins; any line it lacks falls back
to this flat folder. A folder counts as a pack once it holds at least one audio
file.

Example: put a deep, reverbed "victory" read into win.title.ogg -- or a whole
voice set under narration/soundmon-1/ -- flip Narration on in SETTINGS, win a
run, and hear it.

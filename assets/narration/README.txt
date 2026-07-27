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

Keys currently spoken by the game:

  win.title       the victory banner  ("V I C T O R Y")
  lose.title      the death banner    ("Y O U   D I E D")
  intro.descent   the game-open TEXT CRAWL ("THE DESCENT"). When a file exists the
                  spoken line plays OVER the crawl and the per-glyph blips go quiet
                  (the voice covers it); absent -> the crawl blips as before. The
                  on-screen wording is dynamic (your name, gold, key level), so this
                  is an atmospheric read, not a word-for-word match -- write it as a
                  general narration of the descent.

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

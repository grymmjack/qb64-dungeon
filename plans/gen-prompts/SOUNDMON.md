# soundmon — fill the MISSING audio in qb64-dungeon

Game repo: `~/git/qb64-dungeon`   (soundmon lives at `~/git/soundmon`, CLI `~/.local/bin/soundmon`)

## The work list comes from the game

```bash
cd ~/git/qb64-dungeon
./dungeon.run audiomanifest audit pack=<PACK>                 # everything missing
./dungeon.run audiomanifest audit pack=<PACK> | grep '^sfx/'
./dungeon.run audiomanifest audit pack=<PACK> | grep '^music/'
./dungeon.run audiomanifest audit pack=<PACK> | grep '^narration/'
```

`audit` = only what is missing. `pack=<name>` is **strict** (audio present only in
`default/` still counts as missing for that pack).

## Line formats

```
sfx/<name>       | <seconds> | <prompt>
music/<name>     | <seconds> | <prompt>
narration/<key>  | <the exact words to speak>
```

**Narration is different and it matters:** the third field is not a prompt, it is
the LINE TO SPEAK, verbatim. The filename is a `strings.txt` key
(`narration/win.title`), and the game plays it by key.

## Where the file goes — and the extension is your choice

```
sfx/door  ->  ~/git/qb64-dungeon/assets/sfx/<PACK>/door.<ext>
```

Manifest audio paths carry **no extension** on purpose. The game resolves
`.ogg` / `.mp3` / `.flac` / `.wav` in the player's preferred order, so ship
whichever suits the pack. Tracker modules (`.rad`/`.mod`/`.xm`/`.it`/`.s3m`)
always win for MUSIC and are very welcome — the game's own music is `.rad`.

## Packs to fill (existing only — do NOT create new packs)

**Not packs, skip them:** `bitwig` (a DAW project dir), `record-voiceovers.sh`.

| pack | sfx | music | narration |
|---|---|---|---|
| `default`                        | 49 | 22 | 282 |
| `grymmjack`                      | 66 | 24 | 282 |
| `soundmon-adlib`                 | 20 | 0  | 282 |
| `soundmon-chiptune`              | 20 | 0  | 282 |
| `soundmon-cinematic`             | 20 | 0  | 282 |
| `soundmon-darkscary`             | 20 | 0  | 282 |
| `soundmon-dungeonsynth`          | 20 | 0  | 282 |
| `soundmon-orchestral`            | 20 | 0  | 282 |
| `soundmon-orcish`                | 20 | 0  | 282 |
| `soundmon-souls`                 | 20 | 0  | 282 |
| `found-on-disk-8bit-from-claude` | 20 | 24 | 282 |
| `found-on-disk-dnd-from-claude`  | 20 | 24 | 282 |
| `found-on-disk-from-claude`      | 20 | 24 | 282 |

### Read this before starting — the totals are the whole decision

Filling every row above is **~4,000 clips**, and 3,666 of them are narration:
the same 282 lines re-voiced 13 times. **No narration exists in ANY pack today.**

Suggested order, cheapest-useful-first:

1. **SFX only, all 13 packs** — ~315 files. Every pack becomes complete for
   effects, which is what the player actually hears constantly.
2. **Narration for ONE pack first** (`grymmjack`, or whichever voice you want as
   the default) — 282 lines. Listen to it in game before committing 12 more voices.
3. **Music** where it is 0 — only `default`, `grymmjack` and the three
   `found-on-disk-*` packs need any; the `soundmon-*` packs are already complete.

The game degrades per FILE, not per pack: a partial pack falls back to `default/`
for anything it is missing, so shipping SFX-only packs is a fully supported state,
not a half-finished one.

Note the farm still works with servers down for real synthesis:
`--chipfx` (sfxr PSG), `--chip` (NES 2A03), `--opl` (Nuked OPL3 — same chip family
as the game's `.rad` music).

## Verify when done

```bash
cd ~/git/qb64-dungeon
./dungeon.run audiomanifest audit pack=<PACK> | head -1   # expect: # MISSING: 0
```

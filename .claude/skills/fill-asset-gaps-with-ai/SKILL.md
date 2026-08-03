---
name: fill-asset-gaps-with-ai
description: "Find every MISSING or PLACEHOLDER game asset and generate it with the local AI farms — pixelmon (pixel art), ansimon (ANSI art), soundmon (sfx, music, narration). Reads the game's own manifest AUDIT modes so the work list is computed, never eyeballed, then verifies each file landed as real art rather than another stand-in. Use when the user says 'fill the asset gaps', 'generate the missing art/sounds', 'what art is missing', 'run pixelmon/ansimon/soundmon on the gaps', or points at placeholder art still showing in game."
argument-hint: "Which asset kinds (art / ansi / sfx / music / narration / all), and which pack?"
---

# Fill asset gaps with AI

Close the gap between what the game ASKS for and what is actually on disk, using the
local generators. The game already knows what is missing — this skill's job is to ask
it properly, generate only what it names, and then **prove** each file is real.

## The one rule that matters

**A missing asset and a PLACEHOLDER asset are the same problem, and only the second one
lies to you.** A stand-in is a file: every "does it exist" check says yes, the generator
skips it, and the game happily draws it. So:

- Never decide what is missing by listing directories or looking at the game.
- Never report an asset done because a file appeared.
- **Always** re-run the audit afterwards and require the MISSING count to have dropped.

The audits already reject placeholder PNGs (by colour count) and blank ANSI (zero
glyphs), so "the audit no longer lists it" is real proof. Nothing else is.

## Step 1 — build the work list from the audits

Run from the game's repo root. Every manifest takes `audit` (only what is missing) and
`pack=<name>`. Add `nocolor` so the output parses cleanly.

```bash
./dungeon.run imagemanifest  audit nocolor   # entity pixel-art + ansi-art
./dungeon.run uimanifest     audit nocolor   # decorative ANSI chrome (logos, menu pieces)
./dungeon.run fightmanifest  audit nocolor   # tactical-combat portraits
./dungeon.run audiomanifest  audit nocolor   # sfx + music + narration
```

Line 1 of each is `# MISSING: N` — fetchable with `head -1`. The body is the work list,
one asset per line:

```
pixel-art/items/sword.png        | item | 128   | a plain but well-kept steel longsword, ...
ansi-art/items/sword.ans         | item | 16x12 | a plain but well-kept steel longsword, ...
sfx/bump                         | 0.18 | one short dull thud of walking into a stone wall
narration/win.title              | Victory.
```

Art lines are `path | style | size | prompt`. Audio lines are `path | seconds | prompt`,
except **narration**, which is `path | the literal words to speak`.

If the binary is stale, rebuild first — a manifest is computed from the loaded tables, so
an old binary audits an old game.

**The pack matters.** A manifest path is `<category>/<rest>`; the pack directory goes
*between* them:

```
pixel-art/items/sword.png  ->  assets/pixel-art/<pack>/items/sword.png
```

With no `pack=`, the audit uses the packs currently selected in SETTINGS and counts
`default/` as present (the game's real per-file fallback). Pin it with `pack=<name>` when
filling a specific pack. **Say which pack you are filling before you generate anything** —
art landing in the wrong pack is the exact failure that leaves placeholders on screen
while every audit reports zero missing.

## Step 2 — generate, one asset at a time

The three CLIs share `--name`, `--output-to`, `--no-subdirs`, `--server` and `--no-open`. Use the
**authored prompt from the manifest verbatim** — it is the art direction, already tuned,
and rewriting it is how a pack drifts out of style.

`--batch` is a comma list of *subjects* only. It carries no per-item prompt and no
destination filename, so it is the wrong tool here. Drive one asset per invocation.

| manifest path | generator | command shape |
|---|---|---|
| `pixel-art/…png` | pixelmon | `pixelmon "<prompt>" --size <size> --transparent --name <base> --output-to <dir> --no-subdirs --no-open` |
| `ansi-art/…ans` | ansimon | `ansimon "<prompt>" --size <cols>x<rows> --name <base> --output-to <dir> --no-subdirs --no-open` |
| `sfx/<name>` | soundmon | `soundmon "<prompt>" --seconds <n> --name <base> --output-to <dir> --no-subdirs --no-open` |
| `music/<name>` | soundmon | `soundmon "<prompt>" --music --seconds <n> --name <base> --output-to <dir> --no-subdirs --no-open` |
| `narration/<key>` | soundmon | `soundmon --narrate-file <rows.txt> --voice <voice> --output-to <dir> --no-open` |

Notes that save a re-run:

- **`--no-open` on EVERY call, always.** All three tools auto-open the result in the default
  viewer when they finish. That is right when a human is making one sprite and wrong here: an
  unattended fill of twenty assets opens twenty windows over whatever the user is doing. It is
  the single easiest flag to forget and the most annoying to forget.
- **`--size`** comes straight from the manifest. Pixel art is `128` or `512x512`; ANSI is
  **characters**, `16x12`, and must be passed as `--size 16x12` (ansimon has no
  `--cols`/`--rows`).
- **Narration is a batch by design.** `--narrate-file` reads `key | text` rows — the exact
  shape the audiomanifest already emits. Filter the audit's narration lines into a file and
  hand the whole thing over in one call; do not loop.
- **Sub-second SFX**: `--seconds` takes a float, so the manifest's `0.18` is accepted — but
  soundmon conditions the model on `max(1, round(seconds))`, so anything under a second comes
  back as roughly one second and relies on the default silence trim. Expect that; it is not a
  failure. Pass the manifest value anyway (it still shapes the sound), and check the result is
  actually short before calling it done.
- **Transparency**: entity/item pixel art wants `--transparent`. Full-bleed art (screens,
  events, anything the manifest sizes wide like `512x256`) does not.
- **`--name` is a BASE, not the filename. You MUST rename afterwards.** Every tool decorates
  its output with size, seed and a suffix — `--name sword` produces
  `sword_128x128_none_s264551481_sprite_00001_.png`, not `sword.png`. The game looks for the
  exact manifest name and finds nothing, so the audit is unchanged and the run looks like it
  silently did nothing *even though the art generated perfectly*. After each call, move the
  newest matching output onto the exact path:

  ```bash
  newest=$(ls -t "$dir/${base}"_*.png | head -1)   # .ans for ansimon
  mv -f "$newest" "$dir/$base.png"
  ```

  ansimon emits **three** files per run — `.ans`, `.xb` and a preview `.png`. Take the `.ans`
  (and the `.xb` if the pack keeps them alongside; this repo does, under the plain basename).
  Delete the preview and any other seed-named leftovers, or the pack fills with clutter.
- **Filenames must match the manifest exactly.** Monster paths include their category subfolder
  (`monsters/beasts/goblin.png`) — write to that exact directory, the game only looks there.
- **LOOK at what came back.** The audit proves a file is real art, not that it is the RIGHT art:
  a prompt asking for a "single item icon" came back as three swords in one frame, which passes
  every automated check and is useless as an icon. View each generated sprite before reporting
  it done, and re-roll the ones that missed — a re-roll is ~20 seconds.

### The render farm

Read the tool's own `servers.json` rather than assuming. Entries whose key starts with `_`
are disabled — skip them.

```bash
python3 -c "import json;print(','.join(k for k in json.load(open('$HOME/pixelmon/servers.json')) if not k.startswith('_')))"
```

Locations: pixelmon `~/pixelmon`, ansimon `~/git/ansimon`, soundmon `~/git/soundmon`.
The farm lists differ per tool. Pass `--server a,b,c` to fan out; leave it off for local.
Generation is slow — run it in the background and report progress rather than blocking.

## Step 3 — verify, then report

```bash
./dungeon.run imagemanifest audit nocolor | head -1     # expect a LOWER number
```

For each asset claimed done, the audit must no longer list it. If a path is still listed
after a file appeared, the generator produced something the audit rejects — a placeholder,
or a blank canvas — and it is **not** done. Say so; do not quietly count it.

Then run the project's gate (`tests/run-tests.sh` here) before reporting finished.

Report: how many gaps were found, how many closed, and **name anything still open**. A
partial fill honestly reported is worth far more than a clean-sounding total.

## Traps this skill exists because of

- **Do not empty `assets/PLACEHOLDERS.txt`.** It records stand-ins as `path|bytes` and an
  entry retires itself when the size changes, so it does not go stale. It has been emptied
  once, by someone who believed the art was finished, and three placeholders then audited
  as done permanently. If it seems wrong, the content checks are the authority — leave the
  list alone.
- **Check the pack you are writing to.** Real art generated into `pixelmon-1` while the game
  had `default` selected is exactly why placeholders stayed on screen with a clean audit.
- **A well-formed file can still be empty.** A blank `.ans` with a valid SAUCE record is the
  right size and renders nothing. The audit catches it; your eyes will not.
- **Never claim a batch "filled the gaps" without the after-count.** That claim, made once
  without verifying, is the origin of every problem above.

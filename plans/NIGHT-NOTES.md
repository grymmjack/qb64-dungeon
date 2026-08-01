# Night session notes — 2026-08-01

Working notes from the autonomous run. `plans/PLANS.todo` stays clean; the detail lives here.

---

## Generator availability (checked at the start of the session)

| tool | on PATH | usable tonight? |
|---|---|---|
| `pixelmon` | `~/.local/bin/pixelmon` | **No** — repo dir `~/git/pixelmon` does not exist, and no ComfyUI server is up |
| `soundmon` | `~/.local/bin/soundmon` | **Partly** — the *synthesis* paths work; the model paths do not |
| `ansimon`  | `~/.local/bin/ansimon`  | **No** — needs ComfyUI |

All three ComfyUI servers in `~/git/soundmon/servers.json` were unreachable:

```
local 127.0.0.1:8188     unreachable
rtx   192.168.1.77:8188  unreachable
mac   192.168.1.120:8188 unreachable
```

So anything model-backed is blocked: **Kokoro narration audio, Stable Audio SFX, ACE-Step
music, pixel art, ANSI art.** Those items are left open in PLANS.todo and listed under
"Blocked on a GPU server" below.

**What still works with no GPU at all** — soundmon's real-synthesis paths:

- `--chipfx` — sfxr-style PSG effect recipes (verified working offline)
- `--chip` — NES 2A03 chiptune
- `--opl` — Nuked OPL3 (the same chip family as the game's `.rad` music)

Invocation that works (note: `-o` is not a flag; it is `--output-to`):

```bash
soundmon "a heavy wooden door slam" --chipfx --name door --output-to <dir> --no-open
```

`--chipfx` picks a recipe by keyword from the prompt. The recipe list, read out of
`~/git/soundmon/chipfx.py`:

```
alarm bighit blip boom breakdoor bump chest chime click coin confirmup crack crash creak crit
curio death dice_edge diceland diceroll dice_settle door drone errordown fanfare fire fireball
fizzle fumble growl heartbeat hiss hit hurt idle key levelup lose maxhit metal miss move noise
rattle savebad saveok search secret secretpass select shimmer step strongdoor sweepup teleport
thud trap treasure voice whoosh win
```

That list maps almost one-to-one onto the game's `Sfx` dispatcher names, and it covers most of
the ambient set the todo asks for (`thud`, `creak`, `crash`, `rattle`, `drone`, `growl`, `hiss`,
`noise`, `whoosh`).

---

## Done this session

### Combat + level-up flavor text (PLANS: "Narration Small Tweaks")

The complaint was repetition. The cause was concrete: **`class_events.txt` had exactly one line
per event**, so every single player hit, crit, miss and fumble printed the same sentence.

Counts before → after, in the `*` default pools:

| file | event | before | after |
|---|---|---|---|
| `class_events` | attack | 1 | 12 |
| `class_events` | crit | 1 | 11 |
| `monster_events` | attack | 2 | 12 |
| `monster_events` | crit | 1 | 11 |
| `monster_events` | death | 2 | 12 |
| `monster_events` | killcrit | — | 10 (new) |

All lines are the ones authored in PLANS.todo, lightly copy-edited for typos
(`it's`→`its`, `wreaks`→`reeks`, `prowress`→`prowess`).

**New `killcrit` event (code 6).** A crit that *finishes* a monster now gets its own aftermath
text instead of the ordinary death line — the plain death line reads as a quiet expiry, which is
the wrong note right after you have opened something up. `fx_critkill` is set in `DoCombatDnD`
where crit damage takes `mhp_now` to 0 and consumed in `ClaimTreasure` (one kill, one aftermath).

**New `assets/flavor/<pack>/levelup.txt`** — 10 lines, loaded as flavor pool 5, shown in the
LEVEL UP banner via `LevelUpSaying$`. Empty pool = the banner keeps its mechanical text only, so
a data pack that omits the file loses nothing but flavour.

---

## Blocked on a GPU server (ComfyUI down)

These are ready to run the moment a server is up; the commands are written out so it is a
copy-paste job.

- **Narration audio** for the new combat lines (`soundmon --narrate-file … --voice bm_george`).
  The game's narration is keyed by `strings.txt` key, so each line needs a stable key first.
- **Monster/item name narration** ("Goblins bar your path…") — needs per-monster audio.
- **Pixel art / ANSI art** for anything still missing from the manifests.

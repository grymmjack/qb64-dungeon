# Night session notes — 2026-08-01

> ## STANDING RULE for unattended / overnight runs
>
> **Do not call `AskUserQuestion` when the user has said they are away.** It is *not* a
> permission prompt, so "bypass permissions" has no effect on it, and this machine's
> `askUserQuestionTimeout` is `"never"` — one question stalls the entire run until someone
> comes back to the keyboard. It cost most of a night once already.
>
> Instead: pick the most defensible option, do the work, and record the decision **and the
> alternatives I rejected** here under "Judgement calls" so it can be reviewed and reversed.
> Everything goes through git, so a wrong call is one `git revert` away — which is a far
> cheaper failure than a run that did nothing.
>
> Related: the persisted `defaultMode` in `~/.claude/settings.json` is `"auto"`, not bypass.
> Bypass enabled per-session via `/permissions` will not survive a resume.

Working notes from the autonomous run. `plans/PLANS.todo` stays clean; the detail lives here.

---

## Generator availability (checked at the start of the session)

| tool | repo | usable that night? |
|---|---|---|
| `pixelmon` | `~/pixelmon` (**not** `~/git/`) | **No** — no ComfyUI server was up |
| `soundmon` | `~/git/soundmon` | **Partly** — the *synthesis* paths work; the model paths do not |
| `ansimon`  | `~/git/ansimon` | **No** — needs ComfyUI |

CORRECTION (26-08-01, from Rick): I looked for pixelmon at `~/git/pixelmon` and wrongly concluded
it was absent. It is at **`~/pixelmon`**, and its `servers.json` is the FULLER farm list —
`local` / `titan` 192.168.1.172 / `rtx` / `mac`, where soundmon's has no `titan`. Only the
servers being down was real; pixelmon itself was fine.

All three ComfyUI servers in `~/git/soundmon/servers.json` were unreachable:

```
local 127.0.0.1:8188     unreachable
rtx   192.168.1.77:8188  unreachable
mac   192.168.1.120:8188 unreachable
```

So anything model-backed was blocked: **Kokoro narration audio, Stable Audio SFX, ACE-Step
music, pixel art, ANSI art.**

**What worked with no GPU at all** — soundmon's real-synthesis paths:

- `--chipfx` — sfxr-style PSG effect recipes (**used**, 17 sounds generated)
- `--chip` — NES 2A03 chiptune
- `--opl` — Nuked OPL3 (the same chip family as the game's `.rad` music)

Invocation that works (note: `-o` is **not** a flag; it is `--output-to`):

```bash
soundmon "a heavy wooden door slam" --chipfx --name door --seconds 3 \
         --output-to <dir> --no-subdirs --no-open
```

Output lands as `<name>_s<seed>.wav`. `oggenc -q 4` shrinks it ~35× (260 KB → 7.5 KB); note
that **ffmpeg here has no libvorbis**, so `oggenc` is the encoder to use.

`--chipfx` picks a recipe by keyword from the prompt. The recipe list, read out of
`~/git/soundmon/chipfx.py`:

```
alarm bighit blip boom breakdoor bump chest chime click coin confirmup crack crash creak crit
curio death dice_edge diceland diceroll dice_settle door drone errordown fanfare fire fireball
fizzle fumble growl heartbeat hiss hit hurt idle key levelup lose maxhit metal miss move noise
rattle savebad saveok search secret secretpass select shimmer step strongdoor sweepup teleport
thud trap treasure voice whoosh win
```

That list maps almost one-to-one onto the game's `Sfx` dispatcher names.

---

## Done this session

Commits, oldest first: `4e24ad4 ca17b54 7a62fe2 8541efa ff3fd56 1e2b471 97471a4 07ac45f`.

### 1. Sector geometry retired (`4e24ad4`)

Three files used to say where a dungeon level is — the `sectors.txt` rectangles, the
hand-painted `board-132x50-sector-mask.ans`, and the art itself. When the copies disagreed with
the art, **rooms vanished**.

`DeriveSectors` (game/SECTOR.bas) now computes it from the art at board build: tight per-colour
bounding boxes, then expand each a row/column at a time until it meets a neighbour or the board
edge (the expansion is what claims the **corridors**, which state no colour). Expansion is
stepwise and round-robin so no level races ahead.

It samples `FULL_COLLIDE`, never the display board — over the whole picture the logo, legend and
frame all paint in level colours and the derivation fails 15 ways.

The mask file and the `sectorgen` dev mode are **deleted**. `sectors.txt` keeps only
`id | label | colour` (the col/row columns are ignored but kept so existing data packs parse).

### 2. Combat + level-up flavor (`ca17b54`)

The repetition complaint had a concrete cause: **`class_events.txt` had exactly one line per
event**, so every player hit, crit, miss and fumble printed the same sentence forever.

| file | event | before | after |
|---|---|---|---|
| `class_events` | attack | 1 | 12 |
| `class_events` | crit | 1 | 11 |
| `monster_events` | attack | 2 | 12 |
| `monster_events` | crit | 1 | 11 |
| `monster_events` | death | 2 | 12 |
| `monster_events` | killcrit | — | 10 (new) |

Lines are the ones authored in PLANS.todo, copy-edited for typos (`it's`→`its`,
`wreaks`→`reeks`, `prowress`→`prowess`).

New **`killcrit`** event (code 6): a crit that *finishes* a monster gets its own aftermath text
— the plain death line reads as a quiet expiry, wrong right after you have opened something up.
`fx_critkill` is set where crit damage takes `mhp_now` to 0, consumed in `ClaimTreasure`.

New **`assets/flavor/<pack>/levelup.txt`** — 10 lines, flavor pool 5, via `LevelUpSaying$`.

### 3. Ambience (`7a62fe2`)

`AmbienceTick` fires one distant noise every `AMB_SECS_MIN..MAX` seconds of play, weighted by
the level you are standing on. It runs **only in the play loop** — a scream landing on a combat
banner reads as a bug.

Pools are data: `assets/data/<pack>/ambience.txt`, `level | sfx | weight`, level 0 = any level.
`AMB_SECS_MIN = 0` turns it off.

**Ambience never falls back to the tone beeper.** `Sfx` would happily beep a missing effect, but
a PC-speaker blip is a UI sound; a distant noise that is not there should be silence. The picker
checks `SfxHandle&` first — which also means a pack shipping half the ambience still picks
fairly among what it has.

17 sounds generated via `--chipfx` into a **new `assets/sfx/default/`**. That directory did not
exist before and it is the fallback every pack resolves through, so all packs inherit ambience
without shipping it. 440 KB as ogg.

### 4. Pack audit mode (`8541efa`, fixed in `ff3fd56`)

`dungeon.run <any>manifest audit` prints only what the selected packs are **missing**, same
format, count on line 1 (`# MISSING: 137`). Works on all four manifests. Resolution mirrors the
loaders exactly — selected pack, then `default/`, per file.

**First result:** audio 137 missing and *every one of them narration*; image, ui and fight **0
missing**. So the art side of this project is complete and the gap is entirely voice.

### 5. Game tweaks (`1e2b471`, `97471a4`, `07ac45f`)

- **Monster fumble self-damage** at the specified 10/20/30/40. Done as *data*: `effects.txt`
  table 3 is 10 rows read uniformly, so the row count **is** the probability. New effect
  `kind 6` = self-damage EXACT, because `kind 3` rolls `die` and would smear 6/3/1 into a range.
- **Entrance heal** now restores exactly what you started the run with (`hp_start_amount`),
  not to full — so going home matters less as you level, instead of more. Gated on alive
  (1+ HP), actually hurt (<75%), once per trip. `start_heals` shows in the Game Summary as
  "Trips home to heal".
- **Door noise**: each attempt on the *same* reinforced door adds `DOORNOISE_PCT` (25) to the
  chance something investigates; per-door, so switching doors restarts it. On a cleared floor
  it collapses to a flat `DOORNOISE_CLEAR_PCT` (5).
- **The Crypt forces line of sight** (level 9), via a new `fov_forced` flag and `FovOn%`
  (= `opt_fov OR fov_forced`) that every visibility test now asks — **never** by writing
  `opt_fov`, which is the player's saved config and would persist. Wizards are exempt.
- **[TAB] find the player** — dims the board except a disc around you and pulses a ring five
  times. Draws onto CANVAS, repaints from CANVAS_COPY, holds no state.
- **DUNGEON-RULES.md** gained "Clearing a floor", "Going home to heal" and "The 9th level" —
  mechanics that had nowhere explaining them. The in-game `[M] Rules` screen reads this file.

---

## Gotchas found (worth not re-learning)

- **`AudioExt$` already includes the leading dot** (`".ogg"`). Adding one gives `move..ogg` and
  every asset reports missing.
- **Never chain `tests/run-tests.sh` and `git commit` in one shell command.** I did, the gate
  FAILED, and the commit pushed anyway (`8541efa`, fixed by `ff3fd56`).
- **`audit-boundary.sh` catches misfiled globals.** `man_audit` in ENGINE.BI with only a game
  consumer was flagged immediately — the same check that caught the layer fallback earlier.
- **The archiver can run against a stale editor buffer** and silently revert committed
  PLANS.todo content. The tell is line numbers shifting between a read and a grep.
- QB64: `IF a AND b THEN` never short-circuits — the Crypt check is a nested `IF`.

---

## Still blocked on a GPU server

Ready to run the moment ComfyUI is up:

- **Narration audio** — 137 lines, exactly what `dungeon.run audiomanifest audit` prints. The
  manifest emits `narration/<key> | <line to speak>`, so it feeds `soundmon --narrate-file`
  almost directly.
- **Monster/item name narration** ("Goblins bar your path…") — per-monster audio.
- **Torch item art** for the Crypt exemption (below).

## Left open deliberately

- **Torch item** — exempts any class from the Crypt's forced sight; needs a new item code and a
  drop-table entry (10% of random items). The exemption hook is already in place.
- **Door traps on a failed break** (swamp gas / arrow / ambush) — the noise half is done; the
  trap half wants the existing `SpringTrap`/`TRAPS()` machinery and a saving throw per kind.
- **Bestiary showing only discovered monsters** — needs cross-run persistence, which is a save
  format question, not a UI one.
- Everything under "Big UI Tweaks" and "Huge UI Efforts" — these are design work, not chores.


---

## Judgement calls made without asking (2026-08-01)

Per the standing rule above. Each is reversible; the alternative I rejected is stated so the
call can be second-guessed cheaply.

| decision | what I did | the alternative |
|---|---|---|
| Ambient sound source | soundmon `--chipfx` PSG synthesis | Wait for a GPU and use Stable Audio. Rejected: it would have meant shipping nothing, and the PSG sounds are pack-overridable, so replacing them later costs nothing. |
| Where ambience lives | new `assets/sfx/default/` (the shared fallback) | Put them in the active pack. Rejected: then only that one pack has ambience. |
| Fumble odds | rebalanced `effects.txt` table 3 to 10 rows + new `kind 6` | Hardcode the 10/20/30/40 in `DoMonsterFumble`. Rejected: the table is data everywhere else, and code would put the odds out of reach. |
| Entrance heal on old saves | derive `hp_start_amount` from `player_maxhp` once | Bump the save format. Rejected: risks orphaning the player's real save for a cosmetic gain. |
| Crypt forced sight | separate `fov_forced` + `FovOn%` | Set `opt_fov` directly. Rejected: that is the player's *saved* setting and would persist the override into their config. |
| Torch item | left open | Invent an item code and drop-table entry unprompted. Rejected: new player-facing items are a design decision, not a chore. |
| Typos in the authored flavor lines | fixed silently (`it's`→`its`, `wreaks`→`reeks`, `prowress`→`prowess`) | Ship verbatim. Rejected: they read as errors in-game. Easy to revert — they are one commit. |

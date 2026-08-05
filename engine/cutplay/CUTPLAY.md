# `cutplay.run` — the CUT player

The standalone player and authoring tool for `.cut` scenes.

Two separate things, two separate references:

| | |
|---|---|
| **the CUT language** — what you write in a `.cut` file | [assets/cutscenes/CUT-DSL.md](../../assets/cutscenes/CUT-DSL.md) |
| **the CUT player** — the tool you run scenes with | this file |

```bash
qb64pe -w -x engine/cutplay/CUTPLAY.bas -o cutplay.run    # from the REPO ROOT
```

> The binary **must** live at the repo root. QB64PE chdirs to the executable at
> startup, so `assets/...` only resolves when `cutplay.run` sits beside
> `assets/`. Built into a subdirectory it silently fails every file check —
> everything looks missing and nothing says why.

---

## 1. The four modes

```bash
cutplay.run <file.cut> [key=value ...]        # play it
cutplay.run lint <file.cut|all>               # check it without playing
cutplay.run shot <file.cut> <secs> <out.png>  # one frame, at an exact time
cutplay.run selftest                          # the engine's own assertions
```

Plus two switches that work with any of them:

| | |
|---|---|
| `auto` | no keypresses needed — every beat times out on its own |
| `quiet` | open no audio at all (what the headless modes use) |

---

## 2. Keys

**These three are the ENGINE's.** They behave identically here and in the
game, because they are the same code (`CutKeyFeed`):

| | |
|---|---|
| `SPACE` / `ENTER` | advance — first press dumps the rest of the typing line, second moves on |
| `ESC` | skip the scene |
| `1`–`4`, `W`/`S`, arrows | pick a choice |

**These are the player's own** — handled in its loop before anything reaches
the engine, and deliberately absent from the game:

| | |
|---|---|
| `R` | **recompile from disk and restart** |
| `P` | pause — the clock freezes, so nothing snaps forward when you resume |
| `→` | jump one second ahead |
| `L` | loop the scene |
| `S` | screenshot to `cutscene-shot.png` |

They are **the same for every scene**. None of them are per-scene.

> One deliberate difference from the game: **`ESC` always exits here, even for a
> scene marked `noskip`.** That flag is a promise to the player that a beat will
> land; it has no business trapping the author inside a forty-second scene they
> are iterating on. The engine still honours it — the tool overrides.

---

## 3. The loop that makes this worth having

```bash
cutplay.run assets/cutscenes/default/the-long-hall.cut
```

Leave it running. Edit the `.cut` in your editor. Tap **`R`**. It recompiles
from disk and restarts.

Because a scene is compiled at load rather than interpreted line by line, what
you watch after `R` is what the parser actually produced — not a patched-up
version of the previous run.

### Watch a branch instead of hoping about it

Game state comes from the command line, as `key=value`:

```bash
cutplay.run demo.cut class=wizard gold=6000 hp=12 flag.saw_omen=1
```

Those are the **same keys** the `if` conditions and `{token}`s use, so every
arm of every conditional can be seen rather than reasoned about. Anything you
do not set reads as `0` / empty — exactly as it would in the game against a
key the host does not publish.

### The HUD

A strip along the top shows the current op, **the source line it came from**,
the scene clock, the camera position and zoom, and a `MISSING:` count. "Which
line am I looking at" is the question you actually have, and guessing it from
the picture is what makes scripting painful.

---

## 4. Checking a scene without watching it

### `lint`

```bash
cutplay.run lint assets/cutscenes/default/intro.cut
cutplay.run lint all          # every scene in every pack
```

Compiles, and **resolves every asset the scene names**. It walks the compiled
program rather than an execution, so it sees both arms of every conditional,
every frame of an `anim` sequence, and a transition's `to` target.

Exit code is 1 if anything failed, so it drops straight into a gate.

Missing **art** is an error; missing **audio** is a warning — silence is a
legitimate state, and packs ship partial sets.

### `shot`

```bash
cutplay.run shot assets/cutscenes/default/the-long-hall.cut 28 look.png
```

Renders one frame at an exact **simulated** time. The scene is stepped at a
fixed 60 frames per simulated second with the clock driven by the tool, so the
same command lands on the same frame every run — which is what makes it usable
as a regression check.

> This was quietly wrong for a while and is worth knowing about. It used to
> advance the scene by nudging every tween origin back one frame, which looks
> equivalent but is not: real time kept running underneath, so the scene aged
> by one frame **plus however long that frame took to render**. A 20-second pan
> finished by a requested `t` of about 14. `CUT_CLKFIXED` now hands the clock to
> the tool outright.

### `selftest`

190 headless assertions over the parts that can be checked without eyes: the
tokeniser, easing curves, the condition evaluator, `if`/`elseif`/`else` arm
exclusivity, the runaway guard, the sticky font/colour cascade, pipe colours,
`{token}` substitution, GIF decoding, zip entries, parallax, and the clock.

### The gate

```bash
engine/cutplay/run-tests.sh
```

Build → `selftest` → `lint all` → **render every scene** at three fixed times
and require a non-black frame. That last step is the point: a scene can lint
perfectly and draw nothing — wrong layer order, a camera parked off the art, a
transition that never clears — and "nothing" is also exactly what a missing
backdrop looks like.

Everything runs under `xvfb`, never the live display.

---

## 5. When something looks wrong

| what you see | what it usually is |
|---|---|
| A red **`MISSING:`** box | the art did not resolve. `lint` names it. Deliberately loud — "nothing appeared" is indistinguishable from "the layer is behind something" |
| A sprite fills the whole screen | `fill`/`fit` size against the **stage** and silently ignore `scale`. Backdrops want `fill`; sprites want `scale`. The linter warns |
| Black bands between rows of ANSI art | `ANSI_Print` advances at the wrap point **and** on the newline. Rows are normalised at load; if you see this, the art has an unusual width |
| The scene plays silently | normal. A missing sound is silence, never an error. `lint` lists the names |
| A `.gif` never moves | `_LOADIMAGE` returns frame one only; the engine has its own decoder. If it is still static, `lint` will say the file did not resolve |
| Text wraps early or centres off-centre | measured with `_PRINTWIDTH`, so this should not happen — if it does, the font failed to load and it fell back to the grid font |
| You cannot escape a scene | `noskip` — but only in the **game**. `ESC` always works here |

---

## 6. Board-position triggers

A scene can be attached to a CELL, in a data file, with no code:

```
assets/data/<pack>/triggers.txt        level | col | row | scene | once
0 | 16 | 9 | the-long-hall | 1
```

`level` is 1–9 or **0 for any**; `col`/`row` are 0-based like every other cell
coordinate here; `once` remembers it in the save, keyed by scene **and cell**
(the same scene may sit on several cells).

Find coordinates with the in-game `[~]` overlay — the mouse readout names the
cell under the pointer, and left-click teleports you there to check it.

```bash
dungeon.run triggerlint
```

A trigger fails **silently** in two ways that look identical to "nothing is
there": the scene does not exist in this pack, or the cell is not walkable so
the player can never stand on it. `triggerlint` checks both against the same
collision layer the movement code reads, and when a cell is unreachable it
names the nearest one that would work — a chamber's *rectangle* includes its
walls, so "inside the armory" and "somewhere you can stand" are different
questions and nothing tells them apart by eye.

---

## 7. Art on the board

A `.gif` (or a still) can be placed on a board cell, in a data file, with no
code:

```
assets/data/<pack>/overlays.txt      level | col | row | art | scale | lit
0 | 13 | 9 | torch-flame.gif | 0.5 | 1
```

`lit 1` means it only appears once the player has **seen** that cell, so it
obeys fog-of-war and line-of-sight like everything else on the board — a torch
visible through a wall would give the map away.

It animates for free. There is **no board-animation machinery**: the overlay
draws through `Sprite&`, and `Sprite&` animates GIFs for every portrait and
panel in the game. That is the whole reason the animation lives in `ARTPACK`
rather than in any one call site.

```bash
dungeon.run overlaylint
```

Checks the art resolves, warns if a `.gif` decoded to a single frame (a still
wearing an animation's name), and then **actually draws them** and requires the
board's pixels to change — writing `overlayshot.png` so you can look. "The data
is valid" and "you can see it" are different claims.

---

## 8. The editor

```bash
cutplay.run edit assets/cutscenes/default/the-long-hall.cut
```

Three panes: the scene, an op list, and a **timeline**.

| | |
|---|---|
| `SPACE` | play / pause |
| `←` `→` | scrub 0.25s |
| `HOME` `END` | start / end of the scene |
| `↑` `↓` or `[` `]` | pick an op — **and jump the playhead to its moment** |
| `,` `.` | choose which of the op's four numbers to tune |
| `-` `=` | nudge it, with the preview updating |
| `W` | print the tuned value, to type into the `.cut` |
| `R` | recompile from disk |
| `S` | screenshot the whole editor |
| `ESC` | quit |

```bash
cutplay.run editshot <file.cut> <secs> <out.png>    # headless, for checking the UI
```

### How it works, and what that costs

The timeline is **measured, not declared**: a profile pass runs the scene once
with drawing switched off and notes the clock as each instruction goes by. Add
a line to the scene and its marker appears; there is nothing to keep in sync.

Scrubbing is **restart + fast-forward**. The VM is stateful and cannot run
backwards, so "show me t = 12.4" means re-simulating from zero. Not *drawing*
those thrown-away frames is the difference between a scrub bar and a slideshow
— and it is only possible because the host owns the clock (`CUT_CLKFIXED`).

The lanes are art / camera / text / sound / flow, so a camera move and a line
of dialogue at the same instant do not land on top of each other.

### What the editor deliberately does not do

**It does not write to your `.cut`.** Nudging changes the compiled op, so the
preview is honest — but an op is several steps removed from the line that
produced it: `move` emits two, modifiers are keyword-scanned in any order, and
`n1` means something different per command. Rewriting from that would
eventually mangle a carefully commented scene, and a tool that edits your
source has to be right *every* time, not usually.

So the loop is: nudge until it looks right, read the number off `[W]`, type it,
`[R]`. The file stays the one source of truth — which is the same reason there
is no project format.

---

## 9. Checking the wiring

```bash
dungeon.run cutwire
```

Every scene name the **game** can ask for, and whether this pack answers it:
the four set pieces (`intro`, `descend`, `win`, `lose`), one per chamber
(`chamber-` + the chamber's slug), and every board trigger.

Each of those hooks falls through gracefully when a scene is absent — the
chamber plays its text crawl, the ending shows its scorecard, the intro runs
the old crawl. That is deliberate: a pack shipping two scenes should get two
cut-scenes, not ten broken halls.

But it means a **renamed or mistyped** scene is indistinguishable from one that
was never written. Nothing errors, nothing warns, and the beat simply never
happens. `cutwire` prints the map so the difference is visible.

The related dev modes:

| | |
|---|---|
| `dungeon.run cutwire` | scene names the game asks for |
| `dungeon.run triggerlint` | board triggers: missing scene, unwalkable cell |
| `dungeon.run overlaylint` | board art: resolves, animates, changes the board |
| `dungeon.run storyshot` | the Storybook at nothing/mixed/everything seen |
| `dungeon.run gifsprite [f]` | does a `.gif` animate through the ordinary sprite path |

---

## 10. Where things are

```
cutplay.run                        the tool (built to the repo root)
engine/cutplay/CUTPLAY.bas   its source
engine/cutplay/CUTMOCK.bas   the mock host — a second, dungeon-free game
engine/cutplay/CUTTEST.bas   the assertions
engine/cutplay/run-tests.sh  the gate
engine/cutplay/CUTPLAY.md    this file

engine/CUTSCENE.BI                 the engine (shared with the game)
engine/CUTSCENE_{PARSE,COMP,VM,EXEC,DRAW,GIF,ZIP}.bas

assets/cutscenes/CUT-DSL.md        the LANGUAGE reference
assets/cutscenes/<pack>/*.cut      the scenes
assets/cutscenes/<pack>/art/       art that belongs to a scene
```

`CUTMOCK.bas` is worth knowing about: it is a complete second host with no
dungeon in it at all, and it is what proves the engine reaches its host through
eleven `Game_Cut*` hooks and nothing else — the same argument `examples/minimal`
makes for `engine/`.

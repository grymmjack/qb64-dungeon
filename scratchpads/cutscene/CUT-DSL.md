# The `.cut` language

A cut-scene is a plain-text script. It is compiled once when it loads and then
run one frame at a time, so what you write is what plays — there is no hidden
interpretation step to diverge from the file on disk.

```
cutplay.run assets/cutscenes/default/demo.cut        # watch it
cutplay.run lint assets/cutscenes/default/demo.cut   # check it without playing
cutplay.run lint all                                 # check every scene in every pack
```

---

## 1. The shape of a scene

```
scene descend_5
stage 2112x1632

show  bg "rooms/the-crypt.png" scale 11
cam   0.35,0.35 zoom 2.2
music "deep-halls" fadein 3.0

async pan to 0.7,0.6 over 6.0 ease inout
say   "The air turns cold."
say   "Something has been waiting."
waitall

if class == wizard
    say "Your staff hums."
    set saw_omen = 1
else
    say "You have nothing it wants."
end
```

Commands run **top to bottom, one at a time**. A command that takes time
*blocks* — the next line does not start until it finishes. That is what makes
a script read like a screenplay.

`async` breaks that on purpose. See §4.

**Comments** start with `'` (anywhere outside quotes) or `#` (start of line).
Blank lines are ignored. Commands are case-insensitive.

---

## 2. The picture: layers, stage, camera

Three steps, every frame:

```
   LAYERS ──composite──▶ STAGE ──camera crop──▶ SCREEN ──▶ text, menus, transitions
```

- A **layer** is one image (a `.png`, or an `.ans` rendered to an image once at
  load). Layers have their own position, scale, opacity and parallax.
- The **stage** is one big image the layers are composited onto. It is usually
  *bigger than the screen* — that headroom is what there is to pan around in.
- The **camera** takes a rectangle of the stage and blows it up to fill the
  screen.

### `stage <w>x<h>`

Sets the stage size in pixels. Default is exactly the screen: **1056×816**
(132×51 cells at 8×16). A 2× world is `stage 2112x1632`.

Never smaller than the screen; if you ask for smaller you get a warning and the
screen size.

### `cam <x>,<y> [zoom <z>]`

Puts the camera somewhere instantly, no animation. `x`/`y` are **fractions of
the stage** (`0.5,0.5` is dead centre), not pixels — so a scene keeps working
when you resize the stage.

**`zoom 1` shows the largest screen-shaped rectangle that fits in the stage.**
Defined that way the picture can never distort, whatever aspect you made the
stage; and with the default stage, zoom 1 is a plain 1:1 blit. `zoom 2` shows
half as much (twice as close).

### Coordinates, in one table

| | means |
|---|---|
| camera `x,y` | fraction of the **stage** |
| layer `at x,y` | fraction of the **stage**, of the layer's **centre** |
| `caption at c,r` | **character cell** column/row (0-based, 132×51) |
| `iris at x,y` | fraction of the **screen** |

---

## 3. Commands

### Art

```
show  <layer> "<path>" [fade <t>] [at <x>,<y>] [scale <s>|fill|fit] [parallax <p>] [z <n>]
hide  <layer> [fade <t>]
clear
anim  <layer> "<base>" frames <n> fps <f> [loop|once|pingpong] [fade <t>] [at ..] [scale ..]
```

Layers are created on first use and **stack in that order** — the first thing
you `show` is the backdrop. A new layer takes the next free depth, so without
`z` a layer can only ever be drawn *in front* of what is already there; `z 0`
slides one in behind. Paths resolve through the content packs (§7).

`anim` plays a **PNG frame sequence**: `anim fog "fx/fog" frames 8 fps 12 loop`
looks for `fx/fog-01.png` … `fx/fog-08.png`. Two digits, zero-padded — which is
what `ffmpeg -i in.gif out-%02d.png` and ImageMagick both write by default, so
splitting an animated GIF needs no renaming.

```
move       <layer> to <x>,<y> over <t> [ease <e>]
grow       <layer> to <scale> over <t> [ease <e>]
fadelayer  <layer> to <0..1>  over <t> [ease <e>]
```

**`fill` / `fit` size a layer against the stage** instead of against a number
you worked out from the art's dimensions. `fill` covers the stage and crops the
overflow (what a backdrop wants); `fit` puts the whole picture inside and
leaves bars.

Prefer them to `scale` for backdrops. `scale 8` is only correct for one exact
source size, so the day the art is regenerated a little smaller, every scene
using it grows a black border — which is also exactly what a missing backdrop
looks like. That happened here: a generator flag silently produced 128×96
instead of 264×204 and five scenes quietly letterboxed themselves. `fill`
cannot go stale.

**Parallax** is a depth cue: `1` (default) means the layer is pinned to the
stage and moves fully with the camera; `0` means it is pinned to the *camera*
and never appears to move at all. A far ridge at `0.3` drifts while the
foreground sweeps past.

### Camera

```
pan   to <x>,<y> over <t> [ease <e>]
zoom  to <factor> over <t> [ease <e>]
shake <amplitude> [for <t>]
```

`shake` never blocks — it decays on its own, because holding the scene for a
garnish would be wrong.

**Eases:** `linear` `in` `out` `inout` (default for camera) `incubic`
`outcubic` `inoutcubic`/`smooth` `back` `bounce`.
`back` overshoots and settles — that little snap is what makes a camera move
read as deliberate rather than mechanical.

### Transitions

```
cut
fade to|from <colour> over <t>
flash <colour> <t>
dissolve   [to "<path>"] over <t>
wipe       [to "<path>"] dir left|right|up|down over <t>
push       [to "<path>"] dir left|right|up|down over <t>
split      [to "<path>"] over <t>
iris in|out [at <x>,<y>] over <t>
scatter    [to "<path>"] over <t>     ' cell by cell, in random order
scan       [to "<path>"] over <t>     ' scanline sweep
static <t>                            ' glyph noise
crtoff <t>                            ' collapse to a line, then a dot
```

Most transitions **photograph the outgoing frame** and reveal the new picture
from under it. That is why the optional `to "<path>"` exists: the swap has to
happen *inside* the transition, after the photograph. Writing the swap as a
separate line before the transition would photograph the new picture as the old
one, and nothing would appear to happen.

```
dissolve to "gate.png" over 2.0            ' swaps layer `bg` by default
wipe to "gate.png" layer mid dir left over 0.9
```

`fade to black` **stays** black after it elapses — the scene is meant to be
sitting in the dark until something changes it.

The last four are the text-mode family: they work in 8×16 character cells and
look like nothing else.

### Text

```
say "<text>"                       ' subtitle bar
say <Speaker>: "<text>"            ' VN speaker box (with the current portrait)
portrait "<path>" [left|right]     ' portrait "" clears it
title "<title>" ["<subtitle>"] [for <t>]
crawl "<line>" "<line>" ... for <t>
caption "<text>" at <col>,<row> [anchor l|c|r] [color <name>] [fade <t>]
cleartext
```

`say` and `title` **block** until the beat is finished. What "finished" means
is the player's setting, not the script's (§6).

A `caption` does **not** block — it sits there while everything else continues,
and is cleared by `cleartext`.

**Colours:** `black white red blood green blue cyan magenta yellow gold orange
grey bone`, or `#RRGGBB`. An unknown name keeps the built-in colour rather than
failing — the same "missing means unchanged" rule the game's theme system uses.

### Audio

```
music "<name>" [fadein <t>] [once]     ' loops unless you say `once`
musicstop [fade <t>]
sfx "<name>"
narrate "<key>"                        ' a strings.txt key -> spoken audio
cue "<name>" [loop]
```

Names, not paths — they resolve through the audio packs, so a pack can replace
the sound without touching the scene. A missing sound is silence, never an
error.

### Flow

```
wait <t>
waitall            ' join every running async
stopfx             ' cancel running asyncs, landed at their end value
label <name>       ' or  <name>:
jump <label>
stop               ' end the scene early
```

### Conditions

```
if <condition>
    ...
elseif <condition>
    ...
else
    ...
end
```

A condition is:

```
[not] <key> [<op> <value>]      op: ==  !=  =  <>  <  <=  >  >=
```

joined by `and` / `or`, **strictly left to right, no precedence** — `a and b or
c` is `(a and b) or c`. Precedence without parentheses would be a trap, and
parentheses are more language than this needs.

- A bare `<key>` is true when non-zero: `if flag.saw_omen`
- A numeric value compares numerically: `if gold >= 5000`
- A non-numeric value compares as a **string**: `if class == wizard` — no
  quoting needed
- **An unknown key reads as 0 / empty, never an error.** A scene written
  against a key the host does not publish reads as false rather than killing
  the scene mid-play.

### State

```
set   <flag> [= <value>]     ' no value means 1
unset <flag>
grant gold|hp|key <n>
grant item <name>
take  gold <n>
```

### Choices

```
choice "<prompt>"
    option "<text>" -> <label>
    option "<text>" -> <label>
end
```

Up to 4 options. Picked with `1`–`4`, or `W`/`S`/arrows and `SPACE`.

If nobody is going to press anything — attract mode, a `shot`, an unattended
demo loop — the menu **takes its first option after 4 seconds** rather than
parking the scene there forever.

### Scene options

```
scene <name>       ' names the scene (defaults to the filename)
noskip             ' ESC will not skip this one
include "<file>"   ' splice another .cut in place (shared macros, etc.)
```

---

## 4. `async` — doing two things at once

Prefix **any** command with `async` and it starts and returns immediately
instead of blocking:

```
async pan  to 0.7,0.6 over 6.0 ease inout
async zoom to 1.4     over 6.0 ease inout
say "The air turns cold."          ' types WHILE the camera moves
say "Something has been waiting."
waitall                            ' join both camera moves
```

A blocking command and an async one run **identical code**. The only difference
is whether the command also parks the virtual machine on what it started — so
there is no second code path, and no command that works blocking but is subtly
broken async.

`waitall` joins everything in flight. `stopfx` cancels instead, leaving each
one landed on its end value.

---

## 5. Modifier order does not matter

After a command's fixed arguments, the rest of the line is searched for
`fade`, `over`, `at`, `scale`, `ease`, `dir`, `for`, `frames`, `fps`,
`parallax`, `z`, `fill`, `fit`, `layer`, `color`, `anchor` wherever they appear. These are the same
line:

```
show bg "crypt.png" fade 1.0 at 0.5,0.5 scale 1.2
show bg "crypt.png" at 0.5,0.5 scale 1.2 fade 1.0
```

A keyword **inside quotes is never a modifier**, so `say "fade to black"` is
just dialogue.

---

## 6. What the player controls

| | |
|---|---|
| **ESC** | skips the scene — always, unless it declared `noskip` |
| **SPACE / ENTER** | first press dumps the rest of the typing line, second press moves on |
| **1–4, W/S, arrows** | a choice menu |

Whether a finished line waits for a key or times out on its own is a
**setting** (`Manual` / `Auto` / `Off`), not a property of the script. Scripts
stay agnostic; an explicit `for <t>` on a line overrides both.

Skipping **lands** every animation on its end value rather than abandoning it
half way, so whatever follows sees a finished picture.

---

## 7. Where files live

```
assets/cutscenes/<pack>/<name>.cut        the scenes
assets/cutscenes/<pack>/art/...           art that belongs to a scene
assets/pixel-art/<pack>/...               shared sprites
assets/ansi-art/<pack>/...                shared ANSI art
assets/music|sfx|narration/<pack>/...     audio
```

Every path is resolved **pack first, then `default`, per file** — so a partial
pack overrides only what it ships and inherits the rest.

Art can be a `.png` (or jpg/bmp) **or** an `.ans`. An ANSI layer is rendered
through the game's ANSI renderer once at load and is a bitmap from then on, so
the camera pans and zooms it smoothly instead of jumping a whole 8×16 cell.
Black is keyed out, so an ANSI layer composites over what is below it.

**A missing image draws a loud red `MISSING:` box, never nothing.** "Nothing
appeared" is indistinguishable from "the layer is behind something".

---

## 8. Authoring loop

```
cutplay.run <file.cut> [key=value ...]
```

| key | |
|---|---|
| `[R]` | **recompile from disk and restart** — edit in your editor, tap R |
| `[P]` | pause (the clock freezes; nothing snaps forward when you resume) |
| `[→]` | jump one second ahead |
| `[L]` | loop |
| `[S]` | screenshot |
| `[ESC]` | skip / quit |

A HUD along the top shows the current op, **the source line it came from**, the
scene clock, the camera, and a `MISSING:` count.

State comes from the command line, so **every branch can actually be watched**
rather than hoped about:

```
cutplay.run demo.cut class=wizard gold=6000 flag.saw_omen=1
```

Other modes:

```
cutplay.run lint <file|all>              compile only; exit code 1 on errors
cutplay.run shot <file> <secs> <out.png> render at a fixed simulated time
cutplay.run selftest                     headless assertions (111)
```

`shot` steps the scene at a fixed 60 frames per simulated second rather than in
real time, so the same command lands on the same frame every run — which is
what makes it usable as a regression check.

`scratchpads/cutscene/run-tests.sh` is the gate: build, selftest, `lint all`,
and then **render** every scene at three fixed times, requiring a non-black
frame. A scene can lint perfectly and draw nothing — wrong layer order, a
camera parked off the art, a transition that never clears — and "nothing" is
also exactly what a missing backdrop looks like.

---

## 9. Things the compiler will not let you do

An unknown command is a **hard error**, not a silent no-op. So is a jump to a
label that does not exist, a duplicate label, an unclosed `if`, an `option`
outside a `choice`, and `async` with nothing after it. Every diagnostic carries
the **file and line the author actually typed**, including inside an `include`.

And two legal lines the *runtime* will stop:

```
label spin
jump spin
```

That would spin inside a single frame with no window update and no way to press
anything. The VM bounds the instructions per frame and reports it instead.

---

## 10. Embedding the engine in a game

The engine reaches its host through **eleven hooks and nothing else**:

```
Cut_State#(key)              read a number      Cut_ArtPath$(sub)
Cut_StateStr$(key)           read a string      Cut_AudioPath$(kind, name)
Cut_SetFlag(name, value)     persistent flags   Cut_Music / Cut_MusicStop
Cut_Grant(what, amount)      gold/hp/item/key   Cut_Sfx / Cut_Narrate
                                                Cut_AudioTick
```

`CUTMOCK.bas` is a complete second host with no dungeon in it at all — the same
argument `examples/minimal` makes for `engine/`. A game supplies real ones and
includes only `CUT.bi`.

Playing a scene is:

```basic
IF CutCompile%(path) THEN
    CutBegin
    DO
        r = CutTick%          ' one frame: tweens, ops, render
        k = INKEY$: IF LEN(k) THEN CutKeyFeed k
        _DISPLAY
        _LIMIT 60
    LOOP WHILE r = CUT_RUNNING
    CutEnd
END IF
```

Because scenes are addressed by **name** through one entry point, a
board-position trigger table (level + cell → scene, once or repeatable) is a
data file, not an engine change.

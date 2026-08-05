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

**Animated GIFs just work.** `show fx "fire.gif"` decodes every frame, keeps
each frame's own delay, and loops — no `anim`, no frame count, no splitting:

```
show fx "fx/torch.gif" at 0.8,0.4 scale 2
```

`_LOADIMAGE` will open a .gif and hand back only its FIRST frame, which is the
worst kind of failure — the handle is valid, every check passes, and the picture
simply never moves. So the engine carries its own decoder
(`engine/CUTSCENE_GIF.bas`): LZW, interlace, local and global palettes,
transparency, and all four disposal methods. A GIF frame is a *patch* applied to
a running canvas rather than a picture, so frames are composited and snapshotted
whole; decoding them in isolation would give a stack of fragments on black.

Use a frame sequence instead when you want per-frame control (`once`,
`pingpong`, a chosen fps) or when the art needs more than 256 colours.

`anim` plays a **frame sequence** — PNG by default, or full ANSI files with
`ext ans`: `anim fog "fx/fog" frames 8 fps 12 loop`
looks for `fx/fog-01.png` … `fx/fog-08.png`. Two digits, zero-padded — which is
what `ffmpeg -i in.gif out-%02d.png` and ImageMagick both write by default, so
splitting an animated GIF needs no renaming.

**`frames` is optional.** Leave it off and the runtime *probes* — frame 1, 2,
3… until one does not resolve:

```
anim torch "fx/torch" fps 10 ext ans      ' plays however many frames exist
```

So adding a frame to an animation is dropping a file in the folder, with no
number to keep in sync anywhere. Give an explicit `frames <n>` and it warns if
fewer than that resolve — a silently short loop is very hard to spot.

**`ext ans` plays a sequence of complete ANSI files** — separate `.ans` files,
one per frame, *not* one file full of cursor codes. Each is rendered through
`ANSI_Print` once as it loads, so from then on the camera treats a frame of
ANSI exactly like a frame of bitmap: it pans, zooms, scales and fades.

```
anim torch "fx/torch" fps 10 ext ans scale 3 at 0.2,0.55
```

> Rows are normalised on load: padded to the canvas width, line breaks dropped.
> `ANSI_Print` advances at the wrap point **and** again on the newline, so a
> file with both paints a blank row after every painted one — the banding trap
> `MaskNormalize$` exists for on the board masks, reached from another
> direction. `.ans` files stay CRLF on disk (`.gitattributes`, which the board
> art needs), so this has to be fixed at load.

**A `.zip` of ANSI frames plays directly:**

```
anim torch "torch.zip" fps 10 scale 3
```

No `frames`, no `ext` — the archive lists its own entries, sorted by name, so
frame order is the order an artist sees in the folder. This is how ANSI art has
been shipped since the BBS days, and an animation should be able to stay in
that shape.

**ANSI only inside a zip.** A `.ans` is just a string, so it decodes and renders
entirely in memory; `_LOADIMAGE` takes only a path, so a zipped `.png` would
need writing to a temp file first. Loose PNGs work as always.

Every entry is verified against the **CRC-32** the zip already stores, so a
damaged archive is named rather than rendered as confetti.

> The decompression is QB64's own `_INFLATE$`, with one wrinkle: it is *zlib*,
> not raw deflate — it wants a 2-byte header and validates an adler32 trailer,
> and a zip entry has neither. Feeding it a zip entry unmodified does not
> error; it returns a 10 MB buffer of nothing. Both halves are needed:
> `_INFLATE$(CHR$(&H78) + CHR$(&H01) + raw, uncompressedSize)` — the header
> satisfies the format check, and the exact size stops it before the missing
> trailer. The zip header supplies that size for free.

**Animated GIFs need none of this** — `show fx "fire.gif"` decodes every frame
with its own delay and loops.

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

**`shake <amplitude> [for <secs>]`** — amplitude is in **pixels**, and it decays
to nothing over the duration with an ease-out, so it hits hard and settles.

| | |
|---|---|
| `shake 3 for 0.3` | a flinch — a door, a small hit |
| `shake 6 for 0.5` | something lands |
| `shake 9 for 0.6` | a body hits the floor |
| `shake 14 for 0.9` | the room itself |

It never blocks — holding the scene for a garnish would be wrong — so it runs
*under* whatever comes next. It shakes the camera's **source** rectangle rather
than the destination, so no black edge ever creeps in at the screen border.

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

#### Captions can MOVE

```
caption "<text>" at <col>,<row> from <col>,<row> over <secs> [ease <e>]
```

`from` is where it **starts**; `at` is where it **ends up**. Off-screen is just a
coordinate outside the grid, so a negative row drops text in from above:

```
caption "YOU" at 66,13 from 66,-8 over 0.9 ease bounce anchor c color #cc1111 font display$ 96
```

Positions are held as fractions of a cell while moving, so text slides smoothly
rather than snapping cell to cell.

**Timing the impact is a separate line.** The thud and the shake belong *after*
a `wait`, matched to when the text lands — fire them on the same beat as the
caption and the impact sounds while the text is still in the air:

```
caption "DIED" at 66,26 from 66,-12 over 1.0 ease bounce anchor c color #cc1111 font display$ 96
wait 0.95            ' let it fall
sfx   "boom"         ' ...then hit
shake 14 for 0.9
flash blood 0.22
```

`ease bounce` is what makes it read as weight; `ease out` settles politely and
`ease back` overshoots and snaps in. See `deathtext.cut` for the whole thing.

**Colours:** `black white red blood green blue cyan magenta yellow gold orange
grey bone`, or `#RRGGBB`. An unknown name keeps the built-in colour rather than
failing — the same "missing means unchanged" rule the game's theme system uses.

### Fonts, colour and variables

Both are **sticky, exactly like QB64's `COLOR` and `_FONT`**: set it and it stays
set until something sets it again.

```
var  myfont$   = "alagard.ttf"      ' declare once, use anywhere below
var  titlesize = 44
var  ink       = #e8e2d0
var  accent    = gold

font  myfont$ bodysize              ' whole scene, every kind of text
color ink

font  title myfont$ titlesize       ' just titles
color title accent
color speaker accent

say   "..."                          ' uses the sticky values
say   "..." color red                ' one line only -- does NOT stick
title "..." font myfont$ 56
```

Resolved most-specific first:

| | |
|---|---|
| 1 | a per-**line** `color` / `font` |
| 2 | a per-**style** sticky value (`color title gold`) |
| 3 | the **scene-wide** sticky value (`color bone`) |
| 4 | the engine's built-in |

**Styles:** `say` `speaker` `title` `sub` `crawl` `caption` `choice`, or `all`
for the scene-wide value. Setting a colour never clears that style's font, or
the other way round.

**Fonts** are TrueType, from `assets/fonts/ui/` (then `assets/fonts/`), loaded
once and cached. Sizes are points, so `font title "alagard.ttf" 44` is a 44pt
title regardless of the 8×16 grid.

**Variables** are substituted at **compile time**, so a name must be declared
before it is used — like a `#define`. A variable's name inside quoted text is
*not* substituted: dialogue is dialogue. Values keep their quoted-ness, so
`var f$ = "alagard.ttf"` still reads as a filename where it lands.

Because `_common.cut` is `include`d by every scene, putting the `var` and
`font`/`color` lines there is how a pack restyles **all** its cut-scenes at
once — the DSL configuring itself, rather than a second mechanism to keep in
sync.

> Text is laid out by **measured** width (`_PRINTWIDTH`), not by character
> count, so proportional fonts wrap and centre correctly. On the grid font the
> two are identical, so nothing changes for a scene that sets no font.

### Inline colour and tokens

Text carries **pipe colours** — the same `|NN` notation as `PipeCol$` and
PIPEPRINT — and **`{token}`** substitution:

```
say "The |10{class} |12HITS for |04{gold} |07points of damage!"
```

`|00`–`|15` foreground, `|16`–`|23` background, `|PI` a literal `|`. A bare `|`
that is not a valid code is left alone.

**Pipe colours work in any font**, including TTFs — they are drawn through the
same font cascade as everything else, so `font "Gold Box Games.ttf" 26` and
`|12` compose.

`{token}` resolves through **the same state keys as the `if` conditions**, so
there is one namespace to learn: `{class}` `{name}` `{gold}` `{hp}` `{level}`
`{deaths}` `{kills}`… An unknown token reads as `0`, exactly as it does in a
condition. Tokens are filled **once, when the beat starts**, not per frame — a
value that changed mid-line would make the typewriter jump backwards.

> Three things stay in step so this cannot break subtly: width is measured on
> the **stripped** text (or a line mentioning a colour wraps early), the
> typewriter counts **visible** characters (or the reveal stalls three frames
> on every code), and a colour **carries** across a wrapped line (or a long
> coloured phrase snaps back to the default halfway through).

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
cutplay.run selftest                     headless assertions (182)
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

## 9. Recipes

### Restyle every scene in a pack, from one file

`_common.cut` is `include`d by every scene, so the `var` and sticky `font`/
`color` lines belong there. Change those, and the whole pack changes.

```
' _common.cut
var display$ = "alagard.ttf"
var body$    = "dungeon-mode.ttf"
var ink      = #e8e2d0
var accent   = gold

stage 2112x1632
font  body$ 20
color ink
font  title display$ 46
color title accent
```

```
' any scene
include "_common.cut"
title "THE CRYPT"          ' already blackletter, already gold
say   "The air turns cold." ' already the reading face
```

### Text that falls in and lands

See `deathtext.cut` — the short version is: `from` above the screen,
`ease bounce`, then `wait` and hit it with `sfx` + `shake`.

### A size ladder

The same words at several sizes reads more clearly than any description:

```
caption "14pt -- a whisper"      at 66,10 anchor c color #6f7f6f font body$ 14
caption "28pt -- raising it"     at 66,17 anchor c color #d8d0b0 font body$ 28
caption "52pt -- THE ROOM HEARS" at 66,29 anchor c color #ff5555 font display$ 52
```

### A different voice, mid-scene

Because `font`/`color` are sticky, a machine or a god can simply take over and
hand back:

```
font  say mono$ 16
color say #7fffd4
say "SYSTEM: this line, and every line after it, is the C64 face."
font  say body$ 20        ' ...and back
color say ink
```

### Fire, smoke, water

Drop an animated GIF on a layer; it decodes whole and loops at its own delays:

```
show fire "fx/torch.gif" at 0.18,0.55 scale 3
```

### Two things at once

```
async pan  to 0.7,0.6 over 8.0 ease inout
async zoom to 1.4     over 8.0 ease inout
say   "The camera keeps moving while this types."
waitall
```

---

## 10. Things the compiler will not let you do

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

## 11. Embedding the engine in a game

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

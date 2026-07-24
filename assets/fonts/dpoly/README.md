# DPoly dice fonts

Polyhedral-dice fonts used by the game to draw d4/d8/d10/d12/d20 rolls. Each glyph is a
whole die face, so the renderer just prints a character (see `InitDice` / `DrawFontDie` /
`DieGlyphCode` in [include/MENU.bas](../../../include/MENU.bas)).

- **Source:** DPoly, a "game dings" family — <https://www.dafont.com/dpoly.font>
  (first seen on DaFont 2013-05-12, updated 2013-10-08). Author's note: *"DPoly is a
  collection of 'game dings' fonts family based on the common dice used in role-playing
  games. Includes Four-Sider, Six-Sider, Eight-Sider, Ten-Sider, Twelve-Sider, and
  Twenty-Sider types. Each font has 'white' and 'black' versions of the dice and numerous
  additions."*
- Copied here from a local QB64PE sample (`SMcNeill/Dice Fonts`), which demonstrated
  loading them with `_LOADFONT`.

> **Licensing not verified.** No licence file ships with these `.otf` files. DaFont
> licences vary (free / free-for-personal-use / donationware). Confirm the terms on the
> font page before distributing a build, and swap in a freely-licensed alternative if the
> terms don't allow redistribution. The code degrades gracefully: if a font fails to load
> its handle is `0` and the roll falls back to the plain number tumbler.

## Glyph map

`A` is the die's **lowest face**, so face *n* = `CHR$(64 + n)`:

| Font | uppercase (solid) | notes |
|---|---|---|
| Four-Sider | `A`–`D` = 1–4 | `E`–`H` = N/E/S/W compass faces |
| Six-Sider | `A`–`F` = 1–6 | a **numbered square**, not pips — the game uses its own pip art instead |
| Eight-Sider | `A`–`H` = 1–8 | |
| Ten-Sider | `A` = **0**, `B`–`J` = 1–9 | the exception; `K`–`T` = 00/10/…/90 percentile faces |
| Twelve-Sider | `A`–`L` = 1–12 | |
| Twenty-Sider | `A`–`T` = 1–20 | |

**UPPERCASE = solid die, lowercase = outline die** (same face value). Printing the solid
variant in a body colour and then the outline variant on top in an ink colour, under
`_PRINTMODE _KEEPBACKGROUND`, gives a filled die with a contrasting number.

**Do not load these with `"monospace"`** — that forces a fixed cell narrower than the point
size and clips the polyhedra's left/right points. Load proportional and measure with
`_PRINTWIDTH`.

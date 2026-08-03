# Mini-game prototypes

Standalone scratchpads for the mini-games in [plans/PLANS.todo](../../plans/PLANS.todo).
Built here first to get the *mechanic* right, then integrated into the game.

Each prototype has the same three modes, which is what makes building them here worth it:

| mode | what it does |
|---|---|
| `./X.run selftest` | assertions on the MODEL, to stdout, non-zero exit on failure |
| `./X.run shot` | render one representative frame to `X-shot.png` |
| `./X.run` | play it |

**`selftest` is the point.** A mini-game is mostly a small rules engine wearing a screen,
and the rules are what has to be right — so the model is written to be assertable with no
display, and the drawing is kept thin enough that one frame proves it.

**`shot` exists because passing every logic test and drawing nothing is a real failure**,
and only a picture catches it. It caught one immediately: BASIC binds `*` tighter than `\`,
so `(SW - LEN(s)) \ 2 * CW` is `(SW - LEN(s)) \ (2 * CW)` — every line centred at x=6 while
31 assertions passed.

## Building

```bash
cd scratchpads/minigames
qb64pe -w -x RIDDLE.bas -o RIDDLE.run
xvfb-run -a ./RIDDLE.run selftest
xvfb-run -a ./RIDDLE.run shot
```

## The prototypes

| file | PLANS.todo entry | mechanic |
|---|---|---|
| `RIDDLE.bas` | Magic mouths — save WIS | answer matching; WIS buys attempts, a save buys a hint |

## Integration

Nothing here includes the engine. When one moves into the game the MODEL functions transfer
as-is; only presentation is rewritten against `ChroniclePanel` and the theme colours, and
outcomes route through the existing `CurioGain` / `Record*` hooks.

## What is deliberately NOT here

Design authority for anything combat-shaped is `plans/TACTICAL-COMBAT.md` and the
gesture-combat design bible, and its rule is explicit:

> Sword vs bow vs spell is art + tuning over this same engine, not new code.
> **Do NOT build five mini-games.**

So **bow and magic are not prototypes in this folder.** They are tuning of the existing
composure gauge (`engine/GAUGE.bas` + `engine/GESTURE.bas`) — different knobs, different
art, same engine. Building them as separate mini-games would be a direct contradiction of
the plan, and would fragment the one thing the design says should stay unified.

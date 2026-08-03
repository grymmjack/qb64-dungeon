# Bow and magic are not mini-games

You asked for the mini-games "including mazes, riddles, other gestures, bow, magic, etc."
Riddles, the disarm maze and the arrow-slit dodge are built. **Bow and magic are
deliberately not**, and this records why, with the evidence — so the decision is
reviewable rather than something I quietly skipped.

## The plan forbids it, in as many words

`plans/PLANS.todo`, under the deep tactical combat entry:

> **KEY INSIGHT from the prototype: this is ONE composure engine wearing many masks.**
> "Sword vs bow vs spell is art + tuning over this same engine, not new code."
> **Do NOT build five mini-games.**

That is the design authority (`~/git/qb64pe-lab/greywood/gesture-combat-design.md`),
and it is not a stylistic preference — it is the thing that keeps combat learnable.
A player who has mastered the gauge with a sword should already be competent with a
bow; if each weapon were its own game, mastery would not transfer and every weapon
swap would feel like starting over.

## The claim is already TRUE in the code

Not an aspiration — it has been implemented. `engine/GESTURE.bas`:

```basic
FUNCTION CritFlourish% (mon, depth, skill)
    z = GaugeLock%("CRITICAL FLOURISH!", "SPACE to land the follow-through", 0, depth, skill)
    ...  CritFlourish% = GameRoll(xn, player_dmgdie, 0, ...)      ' the WEAPON die

FUNCTION MagicFlourish% (mon, depth, skill, elem)
    z = GaugeLock%("SHAPE THE " + UCASE$(elem) + "!", "SPACE to pour more into it", 0, depth, skill)
    ...  MagicFlourish% = GameRoll(xn, 6, 0, ...)                 ' d6 -- spells roll d6
```

Same gauge, same zones, same payout ladder (crit +2 dice, hit +1, miss +0). The only
differences are **the words on screen** and **which die the bonus rolls**. The comment
in `MagicFlourish%` even states the reasoning: *"deliberately the SAME payout as
CritFlourish, so the player learns one gauge rather than two similar ones."*

Magic is therefore already done. A bow flourish is the same three lines with a third
caption and the bow's die.

## What is actually missing — and it is tuning

`GaugeKnobs` (engine/GAUGE.bas) currently varies the gauge by **skill**, then modulates
by HP, press and depth:

| knob | what it does |
|---|---|
| `crit` / `hit` | zone half-widths — how forgiving the sweet spot is |
| `speed` | sweep rate — how fast the marker crosses |
| `jitter` | per-attempt tempo variance |
| `wander` | how far the sweet spot roams |
| `maxsweeps` | passes allowed before you must commit |

**It does not vary by weapon at all.** That is the real gap, and it is one `SELECT CASE`
away. A sensible first cut, to be tuned by feel rather than shipped as gospel:

| weapon | knob shift | why |
|---|---|---|
| **sword** | baseline | the reference feel everything else is judged against |
| **bow** | `speed` ×0.75, `crit` ×0.85, `maxsweeps` +1 | drawing a bow is slower and steadier: more time to aim, a meaner sweet spot, and you may hold longer before loosing |
| **spell** | `wander` ×1.5, `jitter` ×1.3, `crit` ×1.1 | shaping magic is less about a steady hand than about catching a moving thing — the zone roams more, but is a little wider when you find it |

That is three lines of tuning and no new mechanic, no new screen, no fifth mini-game.

## Recommended next step

Add a `weapon` field to `GAUGEK` and one `SELECT CASE` in `GaugeKnobs`, then wire a
`BowFlourish%` beside the two that exist. It belongs **in the engine**, not in this
folder — there is nothing to prototype, because the engine it would prototype against
is the one already shipping.

If you want it to feel different beyond tuning, the honest lever is **art and framing**
(`"STEADY THE SHOT"` vs `"SHAPE THE FIRE"`), which is exactly what the design bible
means by *art + tuning*.

# ansimon — fill the MISSING ANSI art in qb64-dungeon

Game repo: `~/git/qb64-dungeon`   (ansimon lives at `~/git/ansimon`, CLI `~/.local/bin/ansimon`)

## The work list comes from the game

```bash
cd ~/git/qb64-dungeon
./dungeon.run imagemanifest audit pack=<PACK> | grep '^ansi-art/'
./dungeon.run fightmanifest audit pack=<PACK> | grep '^ansi-art/'
./dungeon.run uimanifest    audit pack=<PACK> | grep '^ansi-art/'
```

`audit` = only what is missing. `pack=<name>` is **strict** (art present only in
`default/` still counts as missing for that pack).

## Line format

```
ansi-art/<path>.ans | <style> | <COLSxROWS> | <prompt>
```

`<COLSxROWS>` is in **CHARACTER cells, and it is not advisory** — ANSI is a fixed
grid and the game scales nothing. Author at exactly that size:

| what | size |
|---|---|
| general monster / item / treasure portraits | `18x12` |
| `strategic-combat/**` (tactical fight screen) | `33x25` |
| `uimanifest` chrome (logos, menu pieces) | as stated, up to `132x50` |

## Where the file goes

```
ansi-art/monsters/beasts/goblin.ans
  -> ~/git/qb64-dungeon/assets/ansi-art/<PACK>/monsters/beasts/goblin.ans
```

**The category subfolder is load-bearing** (`monsters/beasts/`, not `monsters/`) —
art at the wrong path is invisible to the game forever.

## Hard requirements (each of these has broken this game before)

1. **CRLF line endings.** `.ans` is CRLF in this repo, enforced by `.gitattributes`.
2. **iCE colours are ALLOWED and encouraged** — bright backgrounds are correct here.
   But a bright background is spelled with the blink bit, so **SAUCE `TFlags` bit 0
   MUST be set** (`&H13` = iCE + 8px font + square pixels). Leave it clear and every
   editor renders bright backgrounds as their DIM twin — the file is silently wrong
   in the only tool used to edit it, while the game looks fine.
3. **SAUCE must state the real dimensions** (cols x rows), matching the size above.
4. **No trailing blank rows.** Extra rows shift everything.
5. CP437, 16-colour DOS palette, on black, no border and no text unless asked.

Check any file with: `./dungeon.run ansilint <file>` (reports line endings, per-row
printable width, SAUCE dims, the iCE flag, and whether normalisation would change
anything — 0 changed = clean).

## Packs to fill (existing only — do NOT create new packs)

| pack | imagemanifest | fightmanifest | uimanifest |
|---|---|---|---|
| `default`    | 6 | 0 | 0 |
| `ansimon-1`  | 6 | 0 | **16** |

22 files total. The 6 subjects (same in both packs): `items/sword`, `items/staff`,
`items/elven-blade`, `events/rest`, `screens/you-win`, `screens/you-died`.
The 16 extra in `ansimon-1` are UI chrome (logos, menu pieces) — full list from
`./dungeon.run uimanifest audit pack=ansimon-1`.

## Verify when done

```bash
cd ~/git/qb64-dungeon
./dungeon.run uimanifest audit pack=ansimon-1 | head -1     # expect: # MISSING: 0
./dungeon.run ansilint assets/ansi-art/ansimon-1/<file>.ans # per file
./dungeon.run deathshot ansi                                # renders the screen for real
```

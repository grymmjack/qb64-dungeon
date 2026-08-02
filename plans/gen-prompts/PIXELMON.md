# pixelmon — fill the MISSING pixel art in qb64-dungeon

Game repo: `~/git/qb64-dungeon`   (pixelmon lives at `~/pixelmon`, CLI `~/.local/bin/pixelmon`)

## The work list comes from the game, not from me

The game IS the source of truth for every asset path, size and prompt. Do not
hand-author paths — ask the binary:

```bash
cd ~/git/qb64-dungeon
./dungeon.run imagemanifest audit pack=<PACK> | grep '^pixel-art/'
./dungeon.run fightmanifest audit pack=<PACK> | grep '^pixel-art/'
```

`audit` = only what is missing. `pack=<name>` makes it **strict**: art that exists
only in `default/` still counts as missing for that pack, which is what you want
when filling a pack.

## Line format

```
pixel-art/<path>.png | <style> | <size> | <prompt>
```

- `<style>` is a key in pixelmon's `styles.json` (e.g. `darkest`, `item`, `dosrpg`).
- `<size>` is the pixelmon `--size` value (e.g. `128`, or `320x320` for fight art).
- `<prompt>` is the full prompt, already written. Use it as given.

## Where the file goes

Insert the pack directory after the category:

```
pixel-art/monsters/beasts/goblin.png
  -> ~/git/qb64-dungeon/assets/pixel-art/<PACK>/monsters/beasts/goblin.png
```

**The category subfolder is load-bearing.** `monsters/goblin.png` instead of
`monsters/beasts/goblin.png` is invisible to the game forever. Write each file at
exactly the path given.

## Packs to fill (existing only — do NOT create new packs)

| pack | imagemanifest | fightmanifest |
|---|---|---|
| `default`    | 6 | 0 |
| `pixelmon-1` | 6 | 0 |

That is 12 files total. The 6 subjects (same in both packs):
`items/sword`, `items/staff`, `items/elven-blade`, `events/rest`,
`screens/you-win`, `screens/you-died`.

## Verify when done

```bash
cd ~/git/qb64-dungeon
./dungeon.run imagemanifest audit pack=default    | head -1   # expect: # MISSING: 6  (the 6 ansi lines)
./dungeon.run imagemanifest audit pack=pixelmon-1 | head -1
```
Then in-game: `./dungeon.run deathshot pixel` — the weapon planted by the grave
should be a real sword, not a line labelled PLACEHOLDER.

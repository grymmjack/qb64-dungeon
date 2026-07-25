# Pixel-Art Assets

An **optional** pixel-art layer that complements the ANSI board — never replaces it.
Sprite portraits show up in panels (combat, character sheet, and later the Bestiary /
Treasury) when the **Art Style** setting is *Pixel Art* or *Hybrid*. If a sprite doesn't
exist yet, the game just doesn't draw it — everything runs identically without the art.

## How it's generated

The art is produced by [`~/pixelmon`](https://github.com/grymmjack/pixelmon) (SDXL + a
pixel-art LoRA, driven through ComfyUI) across a small render farm.

```
assets/pixel-art/generate.sh            # generate everything not already done
assets/pixel-art/generate.sh monsters   # only a folder (monsters / items / treasures / …)
```

`generate.sh` auto-detects which ComfyUI nodes are up (`local`, `titan`, `rtx`, `mac`),
splits the work across them round-robin, is **resumable** (skips assets already rendered),
and writes a clean `<name>.png` for each asset (plus the raw pixelmon output, which is
git-ignored). Bring more nodes up and re-run to go faster.

## Editing the art

Every asset — its folder, name, style, size, and prompt — lives in
[`manifest.txt`](manifest.txt), one line each. Reword a prompt, change a `style` (a
`~/pixelmon/styles.json` key like `darkest`, `item`, `portrait`, `dosrpg`), or delete a
line to drop it, then re-run `generate.sh` for just that folder. It's the same
edit-a-file-and-regenerate workflow as the game's data tables.

## Layout (mirrors the UI mindmap)

```
monsters/{humanoids,animals,insects,misc,beasts,undead}/*.png   128px sprites
items/*.png            128px item icons          treasures/*.png   128px treasure icons
markers/*.png          128px board markers       events/*.png      128px curio props
classes/*.png          128px class portraits     rooms/*.png       192px location scenes
```

## Sizes

128px native for portraits/icons (displays crisp at 2–3× nearest-neighbor as a combat
portrait or character-sheet art); 192px for room/location scenes. The ANSI board keeps its
own 8×16 text cells — the pixel art lives in panels around it.

## How the game loads it

`include/SPRITES.bas` loads a `<name>.png` on demand, caches it, and blits it scaled-to-fit
into a box (`DrawSpriteFit%`). Monster names are normalised to filenames automatically
(`GIANT RATS` → `monsters/*/giant-rat.png`); classes map by index. All gated on
`opt_artstyle` and graceful when a file is absent.

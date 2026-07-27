assets/ansi-art/ -- AI-generated ANSI / text-mode art (mirrors assets/pixel-art/)
================================================================================

This folder holds ANSI (.ans) versions of the SAME entities as assets/pixel-art/,
in the SAME sub-folder layout -- so an ANSI-art generator can fill it the same way
pixelmon fills pixel-art/. It is the ANSI counterpart to the pixel sprites.

Layout (same as pixel-art/):
  monsters/<category>/<slug>.ans   category = humanoids|animals|insects|misc|beasts|undead
  treasures/<slug>.ans
  items/<slug>.ans
  classes/<hero|elf|superhero|wizard>.ans
  rooms/<slug>.ans                 dungeon location scenes (level + named rooms)
  events/<slug>.ans                curio props

Slugs are the same the engine uses for the PNGs (see assets/pixel-art) -- monster
names via SpriteBase (lowercase, spaces/'/ -> '-', trailing 's' dropped), treasures
/ items via TreBase (keeps plurals, drops "(...)" qualifiers).

Get the exact list of files to generate, each with a prompt:

    dungeon.run imagemanifest        # both pixel-art/*.png AND ansi-art/*.ans + prompts
    dungeon.run imagemanifest | grep '^ansi-art/'    # just this folder

(The UI chrome -- logos, menu pieces -- lives in assets/ansi/, not here; see
`dungeon.run uimanifest`. The board and *-mask .ans files there are FUNCTIONAL
collision/data maps and must NOT be AI-regenerated.)

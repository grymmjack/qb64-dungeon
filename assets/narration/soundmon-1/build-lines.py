#!/usr/bin/env python3
"""Build lines.txt — the narration script — from the game's own data files.

Rather than pointing soundmon at assets/data/*.txt raw, this curates: those
files have different shapes (some end in numbers, some carry {mon}/{weapon}
templates that would be read aloud literally), so we pull only the prose that
is actually meant to be spoken and give each line a stable key. The key becomes
the WAV filename, so the game can look a line up by name.

    ./build-lines.py            # writes lines.txt
    ./generate.sh               # turns lines.txt into WAVs
"""
import os
import re

DATA = os.path.expanduser("~/git/qb64-dungeon/assets/data")
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "lines.txt")


def rows(name):
    """Yield pipe-split, comment-free rows from a data file."""
    path = os.path.join(DATA, name)
    if not os.path.exists(path):
        return
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#"):
                yield [c.strip() for c in line.split("|")]


def key(text, prefix=""):
    k = re.sub(r"[^a-z0-9]+", "_", text.lower()).strip("_")[:44]
    return f"{prefix}{k}" if prefix else k


def titlecase(s):
    """ARMORY -> Armory, KING'S TREASURE -> King's Treasure. The data is all
    caps for the board renderer; spoken aloud it should not be shouted."""
    return re.sub(r"[A-Za-z']+", lambda m: m.group(0).capitalize(), s.lower())


lines = []      # (key, text)
seen = set()


def add(k, text):
    text = " ".join(text.split())
    if not text or k in seen:
        return
    seen.add(k)
    lines.append((k, text))


# --- UI strings, keyed EXACTLY as strings.txt keys them -------------------
# assets/narration/README.txt: the game speaks a line by looking for
# <string-key>.<ext> here. So these filenames are not ours to choose — a file
# named anything else is simply never found. Everything further down uses our
# own keys and is only reachable once someone adds a Narrate "<key>" call.
def unspace(s):
    """"V I C T O R Y" -> "Victory", "Y O U   D I E D" -> "You died".

    The banner strings are letter-spaced for the display renderer; spoken
    literally a TTS engine spells them out. Word boundaries in those banners are
    a WIDER gap than the letter gap, so split on runs of 2+ spaces first —
    collapsing on single spaces alone turns "Y O U   D I E D" into "Youdied".
    """
    s = s.strip()
    groups = re.split(r"\s{2,}", s)
    if len(s) > 1 and all(g and all(len(t) == 1 for t in g.split()) for g in groups):
        return " ".join("".join(g.split()) for g in groups).capitalize()
    return s


def unbracket(s):
    """"[ press any key ]" -> "Press any key." — the brackets are a screen
    convention; read aloud they are noise (or literally spoken)."""
    s = s.strip()
    if s.startswith("[") and s.endswith("]"):
        s = s[1:-1].strip()
        if s and not s.endswith((".", "!", "?")):
            s = s[0].upper() + s[1:] + "."
    return s


for r in rows("strings.txt"):
    if len(r) >= 2 and r[0]:
        add(r[0], unbracket(unspace(r[-1])))

# The game-open text crawl. README.txt calls this out explicitly: the on-screen
# wording is dynamic (name, gold, key level), so this is an ATMOSPHERIC read
# rather than a word-for-word match. Not in strings.txt — it exists only as a
# narration key — so the text lives here.
add("intro.descent",
    "Beneath the hills, the old dungeon waits. Nine levels down, and every one of "
    "them hungry. Others have gone before you. None of them came back up. "
    "Take your steel, take your nerve, and begin the descent.")

# --- Named halls: an announcement as you enter ----------------------------
for r in rows("chambers.txt"):
    if r and r[0]:
        name = titlecase(r[0])
        # "THE CRYPT" already carries its article — don't say "the The Crypt".
        # Possessives ("King's Treasure") don't take one either.
        article = "" if name.lower().startswith("the ") or "'" in name else "the "
        add(key(r[0], "room_"), f"You enter {article}{name}.")

# --- Level / sector announcements -----------------------------------------
for r in rows("sectors.txt"):
    if len(r) >= 2 and r[1]:
        label = r[1]
        m = re.match(r"LEVEL\s+(\d+)\s*-\s*(.+)", label)
        if m:
            add(f"level_{int(m.group(1))}", f"Level {m.group(1)}. {titlecase(m.group(2))}.")

# --- Curios: these are already written in dungeon-master voice ------------
for r in rows("curios.txt"):
    if len(r) >= 4 and r[0]:
        add(key(r[0], "curio_"), r[-1])

# --- Traps: field 7 is the trigger line -----------------------------------
for r in rows("traps.txt"):
    if len(r) >= 7 and r[1]:
        add(key(r[1], "trap_"), r[6])

# --- Monsters and bosses: encounter calls ---------------------------------
for r in rows("monsters.txt"):
    if len(r) >= 3 and r[2]:
        name = titlecase(r[2])
        # The table mixes plural entries (GIANT RATS, GOBLINS) with singular
        # ones (OGRE, GREEN SLIME); the verb has to agree or it reads as broken
        # English when spoken. Trailing 's' is a good enough plural test for
        # this data — no entry ends in 's' while being singular.
        plural = name.endswith("s")
        verb = "block" if plural else "blocks"
        # "A Evil Wizard" / "A Ogre" are audibly wrong once spoken aloud.
        article = "" if plural else ("An " if name[0] in "AEIOU" else "A ")
        add(key(r[2], "mon_"), f"{article}{name} {verb} your path!")
for r in rows("bosses.txt"):
    if len(r) >= 2 and r[1]:
        name = titlecase(r[1])
        add(key(r[1], "boss_"), f"The {name} rises before you!")

with open(OUT, "w", encoding="utf-8") as f:
    f.write("# Narration script, built from assets/data/*.txt by build-lines.py.\n")
    f.write("# Format: key | text   -- the key becomes the WAV filename.\n")
    f.write("# Edit freely; ./generate.sh re-reads this file, it does not rebuild it.\n\n")
    for k, t in lines:
        f.write(f"{k} | {t}\n")

print(f"wrote {len(lines)} lines -> {OUT}")

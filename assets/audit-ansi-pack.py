#!/usr/bin/env python3
"""Audit a generated ANSI art pack against the manifest that specified it.

    audit-ansi-pack.py --pack ansimon-1 [--manifest FILE] [--reject-file OUT]
                       [--metrics]

Every asset is rendered with **pixelview**, not by us, and measured from that
PNG. That is deliberate: this repo's sibling project learned the hard way that
checking your own output with your own renderer proves the two agree, not that
either is right. pixelview is the independent reference.

Checks, in order of how badly they mean "regenerate this":

  missing     the manifest asked for it and it is not there
  unreadable  pixelview could not render it
  wrong-size  rendered pixels != cols*cellw x rows*cellh. The manifest is a
              contract with the layout engine — a portrait that is not exactly
              33x25 cells will not sit in its box.
  control     a raw byte < 0x20 survived into the stream (0x1B would corrupt
              everything after it). Should be impossible now, cheap to prove.
  blank       almost no ink, or fewer than 3 colours: a failed render.
  noise       no flat region anywhere. Real portrait art has a background; mush
              does not, so the largest single-colour share is a good tell.
  duplicate   two assets rendered near-identically. A monster roster where the
              ghoul and the evil hero are the same picture is a bug even though
              each file is individually fine.

`--metrics` prints the measurements for every asset instead of only failures,
which is how the thresholds below were chosen rather than guessed.
"""
import argparse
import os
import re
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image


def strip_sauce(raw):
    """Art bytes only, with any SAUCE trailer and its EOF marker removed.

    SAUCE is a FIXED 128-byte record at the end, so it must be stripped by
    length. Splitting on the last 0x1A — the obvious-looking approach — cuts
    *inside* the record, because SAUCE's binary fields (datatype, filetype,
    tinfo) can themselves be 0x1A. That left the real EOF marker in the "body"
    and reported a control byte in a perfectly good file.
    """
    if len(raw) >= 128 and raw[-128:-123] == b"SAUCE":
        n_comments = raw[-128:][104]     # SAUCE offset 104 = comment line count
        raw = raw[:-128]
        # A COMNT block sits BETWEEN the EOF marker and the record, so once the
        # record is gone the 0x1A is no longer trailing and a naive
        # strip-the-last-0x1A leaves it in the "body" — reported as a stray
        # control byte in every commented file. This is the second time SAUCE
        # framing has produced a false positive here; the count byte is the only
        # thing that says how long the block is, which is exactly why the writer
        # derives it from the same list that builds the block.
        if n_comments:
            blk = 5 + n_comments * 64
            if len(raw) >= blk and raw[-blk:][:5] == b"COMNT":
                raw = raw[:-blk]
        if raw.endswith(b"\x1a"):
            raw = raw[:-1]
    return raw

PIXELVIEW = os.environ.get("PIXELVIEW") or os.path.expanduser(
    "~/git/pixel-viewer/target/release/pixelview")

# Calibrated against the first full ansimon-1 run — run with --metrics to redo
# this rather than adjusting by feel.
MIN_COLOURS = 3         # fewer than 3 distinct colours is a failed render
MIN_INK = 0.05          # <5% non-background: effectively empty
MAX_INK = 0.985         # >98.5% ink: solid slab, no drawing
MIN_FLAT = 0.06         # a render with no flat region at all is pure noise.
                        # NOTE this does NOT catch "looks generic": measured
                        # across 43 assets the flat share ran 24%-62%, and the
                        # piece that read worst by eye (giant-rat) was at 59%,
                        # i.e. near the TOP. Treat it as a catastrophe backstop
                        # only — whether a portrait reads as its subject is not
                        # something this script can tell you.
DUP_DIST = 0.075        # mean per-channel distance on a 16x16 thumbnail.
                        # Across 861 portrait pairs the median was 0.157 and the
                        # max 0.391; the pairs a human called "the same picture"
                        # sat at 0.049-0.071 (hero/wizard, evil-hero/ghoul,
                        # ghoul/goblin). Half the median is the natural cut.


def manifest_rows(path):
    """Rows of `path | style | size | prompt` that name an ansi-art asset.

    The MEDIUM is the path prefix, not a field: field 2 is a styles.json key
    (dark, darkest, dosrpg, item, portrait). Size is a bare CHARACTER grid with
    no cell suffix, so the font cell is derived from the group — the tactical
    screen is 8x8, everything else sits on the 8x16 board canvas. Assume wrong
    and every expected dimension is out by 2x, which would fail the whole pack.
    """
    rows = []
    for line in open(path, encoding="utf-8"):
        if not line.startswith("ansi-art/"):
            continue
        parts = line.split("|")
        if len(parts) < 4:
            continue
        sub = parts[0].strip()[len("ansi-art/"):]
        try:
            cols, rows_ = (int(v) for v in parts[2].strip().split()[0].split("x"))
        except Exception:
            continue
        cw, chh = (8, 8) if sub.startswith("strategic-combat/") else (8, 16)
        rows.append(dict(sub=sub, cols=cols, rows=rows_, cw=cw, ch=chh,
                         style=parts[1].strip()))
    return rows


def measure(png, want=None):
    """Measure a rendered asset, ignoring pixelview's 25-row screen padding.

    `want` is the (w, h) the manifest asked for. Everything except the reported
    dimensions is measured on the ART REGION only — including the padding would
    count hundreds of blank rows as background and inflate every ink and
    flat-region figure, making the thresholds meaningless on small assets.
    """
    a = np.asarray(Image.open(png).convert("RGB"))
    h, w = a.shape[:2]
    pad_ink = False
    art = a
    if want and w == want[0] and h > want[1]:
        art, pad = a[:want[1]], a[want[1]:]
        pad_ink = bool(pad.any())
    flat = art.reshape(-1, 3)
    cols, counts = np.unique(flat, axis=0, return_counts=True)
    bg = cols[counts.argmax()]
    return dict(w=w, h=h, pad_ink=pad_ink,
                colours=len(cols),
                ink=float((flat != bg).any(1).mean()),
                flat=float(counts.max() / len(flat)),
                thumb=np.asarray(Image.fromarray(art).resize((16, 16), Image.BOX),
                                 np.float64) / 255.0)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--pack", required=True)
    ap.add_argument("--manifest", default=None)
    ap.add_argument("--reject-file", default=None)
    ap.add_argument("--metrics", action="store_true")
    ap.add_argument("--assets", default=os.path.dirname(os.path.abspath(__file__)))
    a = ap.parse_args()

    dest = os.path.join(a.assets, "ansi-art", a.pack)
    man = a.manifest
    if not man:
        game = os.path.dirname(a.assets)
        man = tempfile.mktemp()
        # BOTH manifests, matching the generator: imagemanifest is the general
        # art, fightmanifest the tactical screen. Reading one audits half a pack
        # and reports every missing asset from the other half as a failure.
        with open(man, "w") as f:
            for sub in ("imagemanifest", "fightmanifest"):
                subprocess.run([os.path.join(game, "dungeon.run"), sub, "nocolor"],
                               cwd=game, stdout=f, stderr=subprocess.DEVNULL)
    rows = manifest_rows(man)
    if not rows:
        print("  audit: manifest had no ansi rows"); return 2
    if not os.path.exists(PIXELVIEW):
        print(f"  audit: pixelview not found at {PIXELVIEW} — cannot verify"); return 2

    bad, seen, metrics = {}, {}, []
    with tempfile.TemporaryDirectory() as td:
        for r in rows:
            f = os.path.join(dest, r["sub"])
            if not os.path.exists(f):
                bad[r["sub"]] = "missing"; continue
            raw = open(f, "rb").read()
            body = strip_sauce(raw)
            stripped = re.sub(rb"\x1b\[[0-9;]*[@-~]", b"", body)
            ctrl = sum(1 for b in stripped if b < 0x20 and b not in (0x0A, 0x0D))
            png = os.path.join(td, r["sub"].replace("/", "_") + ".png")
            cmd = [PIXELVIEW, "--render", f, "-o", png]
            p = subprocess.run(cmd, capture_output=True, timeout=300)
            if p.returncode != 0 or not os.path.exists(png):
                bad[r["sub"]] = "unreadable"; continue
            want = (r["cols"] * r["cw"], r["rows"] * r["ch"])
            m = measure(png, want)
            m.update(sub=r["sub"], want=f"{want[0]}x{want[1]}", ctrl=ctrl)
            metrics.append(m)

            # A .ANS cannot state its height — it is a stream, and a viewer picks
            # a screen. pixelview uses the classic 25-row minimum, so anything
            # shorter comes back PADDED. Almost every asset here is 3-16 rows, so
            # a strict equality check fails the entire pack: the first version of
            # this script did exactly that, reported 0/139, and the generator
            # dutifully re-rolled all 278 assets three times over. The art was
            # never wrong. Require the art region to match exactly AND the
            # padding to be blank; anything else is a real failure.
            if (m["w"], m["h"]) != want:
                taller = (m["w"] == want[0] and m["h"] > want[1]
                          and not m["pad_ink"])
                if not taller:
                    bad[r["sub"]] = (f"wrong-size {m['w']}x{m['h']} "
                                     f"want {want[0]}x{want[1]}"
                                     + ("" if m["w"] != want[0] or m["h"] <= want[1]
                                        else " (padding not blank)"))
            elif ctrl:
                bad[r["sub"]] = f"control ({ctrl} raw bytes < 0x20)"
            elif m["colours"] < MIN_COLOURS or m["ink"] < MIN_INK:
                bad[r["sub"]] = f"blank (colours {m['colours']}, ink {m['ink']:.1%})"
            elif m["ink"] > MAX_INK:
                bad[r["sub"]] = f"solid (ink {m['ink']:.1%})"
            elif m["flat"] < MIN_FLAT:
                bad[r["sub"]] = f"noise (largest flat region {m['flat']:.1%})"

        # Near-duplicates: compare only same-size assets, keep the first seen.
        for m in metrics:
            if m["sub"] in bad:
                continue
            for other in seen.get((m["w"], m["h"]), []):
                d = float(np.abs(m["thumb"] - other["thumb"]).mean())
                if d < DUP_DIST:
                    bad[m["sub"]] = (f"duplicate of "
                                     f"{os.path.basename(other['sub'])} (d={d:.3f})")
                    break
            else:
                seen.setdefault((m["w"], m["h"]), []).append(m)

    if a.metrics:
        print(f"  {'asset':<44}{'size':>10}{'col':>5}{'ink':>7}{'flat':>7}")
        print("  " + "-" * 73)
        for m in sorted(metrics, key=lambda x: x["flat"]):
            print(f"  {m['sub'][-43:]:<44}{m['w']}x{m['h']:<5}"
                  f"{m['colours']:>5}{m['ink']:>7.1%}{m['flat']:>7.1%}")
        print()

    ok = len(rows) - len(bad)
    print(f"  audit: {ok}/{len(rows)} pass")
    for sub, why in sorted(bad.items()):
        print(f"    ✗ {sub:<48} {why}")
    if a.reject_file:
        with open(a.reject_file, "w") as f:
            for sub in sorted(bad):
                f.write(sub + "\n")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Audit a generated audio pack against the manifest that specified it.

    audit-audio-pack.py --pack soundmon-cinematic [--section music,sfx,narration]
                        [--manifest FILE] [--reject-file OUT] [--metrics]

Same job as audit-ansi-pack.py, same shape, for the other medium. A pack is 207
assets and nobody auditions all of them, so the bad ones ship. grymmjack caught a
hissy SA3 music take (`level1.flac`) by ear AFTER it was in a pack — which is the
wrong place to find it.

Checks, in order of how badly they mean "regenerate this":

  missing     the manifest asked for it and it is not there
  unreadable  soundfile could not open it
  silent      peak below -60 dBFS: the generation produced nothing
  hissy       the music sits too few dB above its own noise floor. THE reason
              this script exists — see the note on the metric below
  clipping    samples pinned at full scale
  dc          a constant offset: wasted headroom, and a thump on playback
  truncated   far shorter than the length the manifest asked for
  duplicate   two assets nearly identical. A pack where `combat-high` and
              `combat-low` are the same recording is a bug even though each file
              is individually fine

WHAT THE HISS METRIC IS, AND TWO THAT FAILED

Not high-frequency energy. A bright orchestral take is legitimately full of
4-16 kHz content — measured, the CLEANEST take here has MORE high-frequency energy
than the hissy one rejected by ear. HF energy cannot separate music from noise.

Not noise floor relative to programme level either, which was the obvious second
idea and is worth recording because it looked convincing and was wrong. Measured
across 131 APPROVED tracks that headroom ran min 3.1 dB, median 17.4 dB — and the
rejected take sat at 8.0 dB, i.e. INSIDE the approved distribution. A gate at
18 dB would have rejected more than half of grymmjack's accepted music. A metric
has to be checked against the accepted corpus, not just against the one bad file.

What does work is asking whether the high frequencies FADE WHEN THE MUSIC DOES:

    quiet_hf   HF energy (6-15 kHz) during the quietest 20% of frames,
               in dB relative to that file's own average HF energy

A constant hiss bed does not modulate with the music, so it barely drops: the
rejected take measures -2.1 dB. Real musical brightness follows the arrangement
and falls away in quiet passages: -11.7, -15.6, -24.1, -55.8 dB on known-good
material. The mechanism is why this one generalises where level-based measures do
not — and being a RATIO WITHIN one file, it does not depend on the container the
way absolute HF does.

`--metrics` prints the measurements for every asset instead of only failures,
which is how the thresholds below were chosen rather than guessed.
"""
import argparse
import os
import subprocess
import sys

import numpy as np

ASSETS = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.dirname(ASSETS)
EXTS = (".flac", ".wav", ".ogg", ".mp3")

# Calibrated with --metrics over the shipped packs; redo it that way rather than
# adjusting by feel.
# THE HISS GATE IS OFF BY DEFAULT, and that is a finding rather than a cop-out.
# Two metrics were tried and both failed against the ACCEPTED corpus:
#
#   headroom over noise floor   approved music ran min 3.1 / median 17.4 dB and
#                               the rejected take sat at 8.0 — inside the range.
#                               A gate at 18 dB rejected >50% of accepted music.
#   quiet-passage HF drop       looked clean on 5 files (rejected -2.1 vs
#                               known-good -11.7 to -55.8) and collapsed on all
#                               131: median -7.0, p95 +0.8, so -6 dB flagged
#                               59/131 = 45% of ACCEPTED tracks.
#
# There is also a confound that invalidates calibration on this corpus outright:
# every approved file is Vorbis, and Vorbis rewrites exactly the high-frequency
# content these metrics read. A gate meant for FLAC cannot be calibrated on OGG.
#
# What is missing is labelled data — a set of FLAC takes marked hissy/clean by ear.
# Until that exists, pass --hiss-gate DB explicitly to opt in, and use --metrics to
# see where a candidate sits. Everything else in this script needs no calibration.
QUIET_HF_DB = None        # None = gate disabled; --hiss-gate DB to enable
MIN_SECONDS_HISS = 3.0    # a one-shot SFX is mostly silence by design, so the
                          # quiet-frame floor means nothing for short files
SILENT_DBFS = -60.0
DC_LIMIT = 0.01
CLIP_SAMPLES = 8
TRUNC_FRAC = 0.5          # shorter than half what the manifest asked for
DUP_DIST = 0.02           # mean abs difference of 64-band log spectra, both
                          # level-normalised. Identical files sit at 0.0.


def manifest_rows(path, sections):
    """Rows of `path | length | prompt` naming an audio asset."""
    rows = []
    for line in open(path, encoding="utf-8", errors="replace"):
        parts = line.split("|")
        p = parts[0].strip()
        sec = p.split("/", 1)[0]
        if sec not in sections or "/" not in p:
            continue
        name = p.split("/", 1)[1]
        if not name:
            continue
        want = None
        if sec != "narration" and len(parts) >= 2:
            # "0.12" or "30-60s loop" — take the upper bound as the target.
            tok = parts[1].strip().replace("s", " ").replace("-", " ").split()
            nums = [float(t) for t in tok if t.replace(".", "", 1).isdigit()]
            want = max(nums) if nums else None
        rows.append(dict(sec=sec, name=name, want=want))
    return rows


def find_asset(dest, name):
    for e in EXTS:
        f = os.path.join(dest, name + e)
        if os.path.exists(f):
            return f
    return None


def measure(path):
    import soundfile as sf
    x, sr = sf.read(path, always_2d=True)
    if len(x) == 0:
        raise ValueError("empty")
    m = x.mean(axis=1).astype(np.float64)
    dur = len(m) / sr
    peak = 20 * np.log10(max(abs(m).max(), 1e-12))
    rms = 20 * np.log10(max(np.sqrt((m ** 2).mean()), 1e-12))

    # Does the HF fade when the music fades? Framewise, 50 ms.
    W = max(64, int(sr * 0.05))
    hf, lo = [], []
    win = np.hanning(W)
    for i in range(0, max(1, len(m) - W), W):
        S = np.abs(np.fft.rfft(m[i:i + W] * win)) ** 2
        fqf = np.fft.rfftfreq(W, 1.0 / sr)
        hf.append(S[(fqf >= 6000) & (fqf < 15000)].sum() + 1e-20)
        lo.append(S[(fqf >= 100) & (fqf < 1000)].sum() + 1e-20)
    hf = np.array(hf); lo = np.array(lo)
    quiet = lo < np.percentile(lo, 20)
    quiet_hf = (10 * np.log10(hf[quiet].mean() / hf.mean())
                if quiet.any() and len(hf) > 4 else 0.0)
    floor = 20 * np.log10(max(np.percentile(
        np.sqrt(np.array([(m[i:i+int(sr*0.02)]**2).mean()
                          for i in range(0, max(1,len(m)-int(sr*0.02)), int(sr*0.02))])), 2), 1e-12))

    # Level-normalised log spectrum, for duplicate detection. Normalising means
    # the same take at two volumes still reads as a duplicate.
    S = np.abs(np.fft.rfft(m * np.hanning(len(m))))
    fq = np.fft.rfftfreq(len(m), 1.0 / sr)
    edges = np.linspace(0, min(15000, sr / 2), 65)
    idx = np.clip(np.searchsorted(fq, edges), 0, len(S) - 1)
    band = np.array([S[idx[i]:max(idx[i] + 1, idx[i + 1])].mean()
                     for i in range(64)])
    band = np.log10(band + 1e-9)
    band = (band - band.mean()) / (band.std() + 1e-9)

    return dict(seconds=dur, rate=sr, peak=float(peak), rms=float(rms),
                floor=float(floor), headroom=float(rms - floor),
                quiet_hf=float(quiet_hf),
                dc=float(m.mean()), clipped=int((np.abs(m) > 0.999).sum()),
                band=band)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--pack", required=True)
    ap.add_argument("--section", default="music,sfx",
                    help="comma list: music,sfx,narration  [music,sfx]")
    ap.add_argument("--manifest", default=None)
    ap.add_argument("--reject-file", default=None,
                    help="write failing asset names here, one per line, for "
                         "FORCE=1 ./generate-from-manifest.sh <sec> <pack> $(cat FILE)")
    ap.add_argument("--metrics", action="store_true")
    ap.add_argument("--hiss-gate", type=float, default=None, metavar="DB",
                    help="enable the hiss check at this quiet-HF-drop threshold "
                         "(e.g. -6). OFF by default: see the note in the header — "
                         "no threshold has survived validation against the "
                         "accepted corpus yet")
    ap.add_argument("--assets", default=ASSETS)
    a = ap.parse_args()

    sections = [s.strip() for s in a.section.split(",") if s.strip()]

    man = a.manifest
    if not man:
        run = os.path.join(GAME, "dungeon.run")
        if not os.path.exists(run):
            sys.exit(f"no manifest and no {run} — build it (F5) or pass --manifest")
        out = subprocess.run([run, "audiomanifest"], cwd=GAME,
                             capture_output=True, text=True)
        man = os.path.join("/tmp", f"audiomanifest-{os.getpid()}.txt")
        open(man, "w").write(out.stdout)

    rows = manifest_rows(man, sections)
    if not rows:
        sys.exit("manifest named no assets for those sections")

    results, rejects = [], {}
    for r in rows:
        dest = os.path.join(a.assets, r["sec"], a.pack)
        f = find_asset(dest, r["name"])
        rec = dict(sec=r["sec"], name=r["name"], want=r["want"], fails=[])
        if f is None:
            rec["fails"].append("missing")
            results.append(rec)
            rejects.setdefault(r["sec"], []).append(r["name"])
            continue
        rec["file"] = f
        try:
            rec.update(measure(f))
        except Exception as e:
            rec["fails"].append(f"unreadable ({e})")
            results.append(rec)
            rejects.setdefault(r["sec"], []).append(r["name"])
            continue
        if rec["peak"] < SILENT_DBFS:
            rec["fails"].append(f"silent (peak {rec['peak']:.1f} dBFS)")
        if abs(rec["dc"]) > DC_LIMIT:
            rec["fails"].append(f"dc {rec['dc']:+.3f}")
        if rec["clipped"] > CLIP_SAMPLES:
            rec["fails"].append(f"clipping ({rec['clipped']})")
        gate = a.hiss_gate if a.hiss_gate is not None else QUIET_HF_DB
        if (gate is not None and rec["seconds"] >= MIN_SECONDS_HISS
                and rec["quiet_hf"] > gate):
            rec["fails"].append(
                f"hissy (HF drops only {rec['quiet_hf']:.1f} dB in quiet "
                f"passages, want <= {gate:.0f})")
        if r["want"] and rec["seconds"] < r["want"] * TRUNC_FRAC:
            rec["fails"].append(f"truncated ({rec['seconds']:.1f}s of {r['want']:.0f}s)")
        if rec["fails"]:
            rejects.setdefault(r["sec"], []).append(r["name"])
        results.append(rec)

    # Duplicates, within a section — cross-section pairs are not comparable.
    for sec in sections:
        have = [r for r in results if r["sec"] == sec and "band" in r]
        for i in range(len(have)):
            for j in range(i + 1, len(have)):
                d = float(np.abs(have[i]["band"] - have[j]["band"]).mean())
                if d < DUP_DIST:
                    msg = f"duplicate of {have[j]['name']} (dist {d:.3f})"
                    if msg not in have[i]["fails"]:
                        have[i]["fails"].append(msg)
                        rejects.setdefault(sec, []).append(have[i]["name"])

    if a.metrics:
        long = [r for r in results if r.get("seconds", 0) >= MIN_SECONDS_HISS]
        if long:
            v = sorted(r["quiet_hf"] for r in long)
            print(f"  {len(v)} assets >= {MIN_SECONDS_HISS}s")
            print(f"  quiet-passage HF drop (dB, less negative = hissier):")
            print(f"    min {v[0]:.1f}  p5 {v[int(.05*len(v))]:.1f}  "
                  f"median {v[len(v)//2]:.1f}  p95 {v[int(.95*len(v))]:.1f}  "
                  f"max {v[-1]:.1f}   gate: "
                  + (f"{a.hiss_gate:.0f}" if a.hiss_gate is not None else "off"))
            print("  hissiest 10:")
            for r in sorted(long, key=lambda r: -r["quiet_hf"])[:10]:
                print(f"    {r['quiet_hf']:6.1f} dB  {r['sec']}/{r['name']}  "
                      f"({r['seconds']:.1f}s)")
        return 0

    bad = [r for r in results if r["fails"]]
    for r in results:
        if not r["fails"]:
            continue
        print(f"  FAIL  {r['sec']}/{r['name']}  --  " + "; ".join(r["fails"]))
    print(f"\n  {len(results)-len(bad)}/{len(results)} passed")
    if a.reject_file and rejects:
        with open(a.reject_file, "w") as fh:
            for sec, names in rejects.items():
                for n in sorted(set(names)):
                    fh.write(f"{sec}\t{n}\n")
        print(f"  wrote {a.reject_file}  ({sum(len(set(v)) for v in rejects.values())} to regenerate)")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Pre-run Stable Audio 3's prompt rewriter for a whole pack, once.

WHY THIS EXISTS — it is a throughput fix, not a feature.

soundmon can run the Qwen rewriter inline as part of each generation, and on a
big card that is fine. On an 8 GB 3070 it is not: Stable Audio 3 medium in fp32
is ~8.6 GB and Qwen 3.5 is ~4.5 GB, so ComfyUI evicts and reloads a model on
EVERY job. Measured: 75.6 s per asset, i.e. ~7 hours for six packs, almost all
of it moving weights across PCIe.

Rewriting every prompt first, caching the results, then generating audio with
the LLM out of the picture turns 336 model swaps into two model loads.

    ./reprompt-cache.py <section> <pack> [--server rtx]

Writes <pack>/prompts.json  { "<asset name>": "<rewritten prompt>" }.
generate-from-manifest.sh uses it when present and passes --no-reprompt, so the
audio pass never touches the LLM.
"""
import argparse
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.dirname(HERE)
SOUNDMON = os.path.expanduser("~/git/soundmon")


def manifest(section):
    """(name, length, prompt) for a section, from the game itself.

    $MANIFEST overrides the live binary, and you almost always want it for a
    multi-step run. dungeon.run is a compiled binary that F5 REPLACES, so it is
    briefly absent during a rebuild — and a run that reads it twenty minutes
    apart can find it missing the second time. That has now killed two separate
    batches. generate-from-manifest.sh already honours $MANIFEST; this reads the
    same variable so a caller can snapshot once and have every stage agree.
    """
    if os.environ.get("MANIFEST") and os.path.exists(os.environ["MANIFEST"]):
        out = open(os.environ["MANIFEST"]).read()
    else:
        exe = os.path.join(GAME, "dungeon.run")
        if not os.path.exists(exe):
            sys.exit(f"no {exe} — build it first (F5), or set $MANIFEST to a snapshot")
        out = subprocess.run([exe, "audiomanifest"],
                             cwd=GAME, capture_output=True, text=True).stdout
    rows = []
    for line in out.splitlines():
        if not line.startswith(section + "/"):
            continue
        parts = [c.strip() for c in line.split("|")]
        if len(parts) < 3:
            continue
        rows.append((parts[0][len(section) + 1:], parts[1], parts[2]))
    return rows


def pack_conf(path):
    conf = {}
    if os.path.exists(path):
        for line in open(path):
            line = line.strip()
            if line.startswith("#") or "=" not in line:
                continue
            k, _, v = line.partition("=")
            conf[k.strip()] = v.strip().strip('"')
    return conf


def rewrite_batch(server, category, items, model, temp=0.7):
    """One ComfyUI job per prompt, but the LLM stays resident throughout."""
    sysp = json.load(open(os.path.join(SOUNDMON, "sa3_reprompt.json")))[category]
    results = {}
    for i, (name, text, seconds) in enumerate(items, 1):
        full = (f"{sysp}\n\nInput: {text}\n"
                f"Target audio length: {max(1, int(round(seconds)))} seconds.\nOutput:")
        g = {"1": {"class_type": "CLIPLoader",
                   "inputs": {"clip_name": model, "type": "stable_diffusion"}},
             "2": {"class_type": "TextGenerate",
                   "inputs": {"clip": ["1", 0], "prompt": full, "max_length": 256,
                              "sampling_mode": "on",
                              "sampling_mode.temperature": temp,
                              "sampling_mode.top_k": 64, "sampling_mode.top_p": 0.95,
                              "sampling_mode.min_p": 0.05,
                              "sampling_mode.repetition_penalty": 1.05,
                              "sampling_mode.seed": 0,
                              "thinking": False, "use_default_template": True}},
             "3": {"class_type": "PreviewAny", "inputs": {"source": ["2", 0]}}}
        data = json.dumps({"prompt": g}).encode()
        try:
            req = urllib.request.Request(server + "/prompt", data=data,
                                         headers={"Content-Type": "application/json"})
            pid = json.loads(urllib.request.urlopen(req, timeout=60).read())["prompt_id"]
        except urllib.error.HTTPError as e:
            print(f"   ✗ {name}: {e.read().decode()[:150]}")
            continue
        text_out = None
        for _ in range(600):
            with urllib.request.urlopen(f"{server}/history/{pid}", timeout=30) as r:
                h = json.loads(r.read())
            if pid in h and h[pid].get("outputs"):
                for node in h[pid]["outputs"].values():
                    for v in node.values():
                        text_out = v[0] if isinstance(v, list) and v else v
                break
            time.sleep(0.5)
        if text_out:
            results[name] = str(text_out).strip()
            print(f"   [{i}/{len(items)}] {name:<18} {results[name][:74]}")
        else:
            print(f"   [{i}/{len(items)}] {name:<18} (no output — will use the raw prompt)")
    return results


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("section", choices=["sfx", "music"])
    ap.add_argument("pack")
    ap.add_argument("--server", default="http://192.168.1.77:8188")
    ap.add_argument("--model", default="qwen3.5_2b_bf16.safetensors")
    a = ap.parse_args()

    dest = os.path.join(HERE, a.section, a.pack)
    conf = pack_conf(os.path.join(dest, "pack.conf"))
    add = conf.get("PROMPT_ADD", "")
    default_secs = float(conf.get("SECONDS_DEF", 3 if a.section == "sfx" else 60))

    items = []
    for name, length, prompt in manifest(a.section):
        # The pack's identity must go INTO the rewriter, not after it — the LLM
        # is otherwise free to contradict the theme it is serving.
        text = f"{prompt}, {add}" if add else prompt
        if a.section == "music":
            digits = "".join(c if c.isdigit() else " " for c in length).split()
            secs = float(digits[-1]) if digits else default_secs
        else:
            secs = default_secs
        items.append((name, text, secs))

    category = "Music" if a.section == "music" else "SFX"
    print(f"▶ rewriting {len(items)} {a.section} prompts for {a.pack} ({category})")
    res = rewrite_batch(a.server, category, items, a.model)

    out = os.path.join(dest, "prompts.json")
    os.makedirs(dest, exist_ok=True)
    json.dump(res, open(out, "w"), indent=2)
    print(f"▶ wrote {len(res)} rewritten prompts -> {out}")
    return 0 if res else 1


if __name__ == "__main__":
    sys.exit(main())

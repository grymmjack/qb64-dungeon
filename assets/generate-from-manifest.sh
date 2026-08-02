#!/usr/bin/env bash
# Generate audio for a pack straight from the game's own manifest.
#
#   ./generate-from-manifest.sh <sfx|music|narration> <pack> [name ...]
#
# `dungeon.run audiomanifest` emits  path | prompt-or-text  for every asset the
# game will ever look up. Driving generation from THAT rather than a
# hand-maintained list means the filenames can't drift out of sync with the
# keys the game asks for — a mismatch is invisible in the audio (the files
# sound perfect) and silently produces assets the game never plays.
#
# By default only MISSING entries are generated, so this is a gap-filler you can
# re-run safely. FORCE=1 regenerates everything.
#
#   ./generate-from-manifest.sh sfx soundmon-1
#   OGG=1 ./generate-from-manifest.sh music soundmon-2
#   VOICE=bm_lewis ./generate-from-manifest.sh narration soundmon-2
#   FORCE=1 ./generate-from-manifest.sh sfx soundmon-1 hit crit
#
# Per-pack knobs live in <pack>/pack.conf (sourced if present):
#   STYLE      extra --style guides appended to every prompt
#   PROMPT_ADD text appended to every prompt (a pack's sonic identity)
#   SECONDS    default length
set -uo pipefail

ASSETS="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
GAME="$(dirname "$ASSETS")"
SECTION="${1:?usage: $0 <sfx|music|narration> <pack> [name ...]}"
PACK="${2:?usage: $0 <sfx|music|narration> <pack> [name ...]}"
shift 2 || true
WANT=("$@")

# FARM = rtx ONLY. grymmjack asked for this twice; recording why so it stops
# drifting back:
#   local  the RX 6600 takes ~13 MINUTES per clip where rtx takes ~5s, and dynamic
#          dispatch makes the whole queue wait on it -- one job blocked the pipeline
#          for 13:43 while rtx sat idle at 0 running / 0 pending. It is also HIS
#          workstation; occupying that GPU is not free to him.
#   mac    has stable_audio_3_small_music/_sfx but NOT stable_audio_3_medium, and
#          only medium works (gotcha 12), so every job routed there fails by
#          construction -- 3 failures per pack before the breaker drops it.
# CPU engines (--chip/--opl/--chipfx/--blip/--narrate) are unaffected: they run
# in-process and never touch this pool.
BOXES="${BOXES:-rtx}"
# FORMAT is the delivery format for EVERY section. FLAC by default: it is
# lossless, so nothing the engines produce is smeared, and it still lands close to
# OGG on size for this material. OGG=1 remains for a lossy build.
FORMAT="${FORMAT:-flac}"              # flac | ogg | wav
[ -n "${OGG:-}" ] && FORMAT=ogg       # legacy OGG=1 still works
case "$FORMAT" in
    flac) OGG_ARG="--flac" ;;
    ogg)  OGG_ARG="--ogg" ;;
    *)    OGG_ARG="" ;;               # wav: soundmon writes it natively
esac
# Keep lossless masters under <pack>/masters/ when asked. They are deliberately
# NOT left beside the pack files: assets/music resolves .wav as the HIGHEST
# quality rung, so a leftover wav silently outranks the ogg the pack ships.
[ -n "${KEEPWAV:-}" ] && OGG_ARG="$OGG_ARG --keep-wav"
# Per-section format override for MUSIC. Chip and OPL output is bit-crushed
# square waves and hard-edged noise, which is the most hostile possible input to
# a lossy codec -- OGG smears exactly the transients that make it sound like a
# tracker rather than a recording. FLAC is lossless, so the crush survives
# byte-for-byte (asserted in soundmon's selfcheck), and it still beats WAV on
# size. The game resolves .flac, so nothing downstream has to change.
MUSIC_FORMAT="${MUSIC_FORMAT:-}"      # flac | ogg | wav | empty = inherit
music_fmt_arg() {
    # Substitute the format flag while KEEPING the other flags OGG_ARG carries
    # (--keep-wav, --no-reprompt); rebuilding it from scratch would drop them.
    local rest="${OGG_ARG#--flac}"; rest="${rest#--ogg}"
    case "$MUSIC_FORMAT" in
        flac) echo "--flac$rest" ;;
        ogg)  echo "--ogg$rest" ;;
        wav)  echo "$rest" ;;
        *)    echo "$OGG_ARG" ;;      # unset: inherit FORMAT
    esac
}
DEST="$ASSETS/$SECTION/$PACK"
mkdir -p "$DEST"

command -v soundmon >/dev/null || { echo "soundmon not on PATH"; exit 1; }
# MANIFEST=<file> uses a pre-captured manifest instead of invoking the game.
# dungeon.run is a compiled binary that F5 replaces, so a rebuild during a long
# run makes it briefly absent — which silently emptied two whole packs once.
if [ -z "${MANIFEST:-}" ]; then
    [ -x "$GAME/dungeon.run" ] || { echo "no $GAME/dungeon.run — build it first (F5)"; exit 1; }
fi

# Pack identity (optional)
STYLE=""; PROMPT_ADD=""; SECONDS_DEF=""
VOICE="${VOICE:-bm_george}"; PITCH="${PITCH:--3}"; SPEED="${SPEED:-0.92}"
# Narration can be spoken (Kokoro) or blipped (JRPG text-box). A chiptune pack
# wants a chiptune voice; a cinematic one wants a narrator. Set NARR_MODE=blip
# in the theme / pack.conf to switch.
SFX_ENGINE="${SFX_ENGINE:-sa3}"       # sa3 | chip | opl
# MUSIC_SOURCE names another pack to TRANSCRIBE from. With it set, chip/opl take
# their tempo, key, chords, melody and bass from that pack's SA3 recording of the
# same track -- the composition is SA3's, the sound is the chip's. Measured, this
# inherits nearly all of the source pack's diversity (0.847 -> 0.798 against a
# source of 0.782), which procedural composition could not reach.
MUSIC_SOURCE="${MUSIC_SOURCE:-}"
MUSIC_ENGINE="${MUSIC_ENGINE:-sa3}"   # sa3 | chip | opl
# Emit the SCORE next to the render, not only the render. A .mod or .rad is a few
# kilobytes against ~3 MB of OGG, it is editable in a real tracker, and QB64 plays
# .rad natively with no decoder at all. Only meaningful for chip/opl, since a
# diffusion model has no score to write out.
#   mod  ProTracker, from the chip engine's own samples  (--chip)
#   rad  Reality AdLib Tracker, OPL instruments          (--opl)
MUSIC_TRACKER="${MUSIC_TRACKER:-}"    # mod | rad | empty
# Ship the SCORE ONLY -- no audio file beside it. For the chiptune and adlib packs
# the tracker file IS the deliverable: QB64 plays .rad natively, .mod plays through
# a replayer, both are a few KB against ~4 MB of FLAC, and both stay editable.
# Rendering audio and then shipping it too would be shipping the same music twice,
# at 300x the size, in the format that is harder to change.
MUSIC_TRACKER_ONLY="${MUSIC_TRACKER_ONLY:-}"   # 1 = keep the score, drop the audio
# Arpeggios, pitch slides and vibrato in the tracker file and the render alike.
MUSIC_CHIPPY="${MUSIC_CHIPPY:-}"      # off | some | lots | max | empty
NARR_MODE="${NARR_MODE:-narrate}"
BLIP_STYLE="${BLIP_STYLE:-synth}"; BLIP_WAVE="${BLIP_WAVE:-square}"
BLIP_RATE="${BLIP_RATE:-14}"; BLIP_PITCH="${BLIP_PITCH:-0}"; BLIP_JITTER="${BLIP_JITTER:-1.5}"
[ -f "$DEST/pack.conf" ] && . "$DEST/pack.conf"

MAN="$(mktemp)"; QUEUE="$(mktemp)"; LOCK="$(mktemp)"
# soundmon prints "seed=N" on success. That line used to go to /dev/null, and the
# rename then stripped the seed from the filename, so NOTHING recorded which seed
# produced which asset — a take that came out badly could not be re-rolled and a
# take that came out well could not be reproduced. Ever. Capture it.
SEEDS_TSV="$DEST/seeds.tsv"
SEEDS_JSON="$DEST/seeds.json"
trap 'rm -f "$MAN" "$QUEUE" "$LOCK" "$QUEUE.lines" /tmp/smout.$$.*' EXIT
if [ -n "${MANIFEST:-}" ] && [ -s "$MANIFEST" ]; then
    cp "$MANIFEST" "$MAN"
else
    ( cd "$GAME" && ./dungeon.run audiomanifest ) > "$MAN" 2>/dev/null
fi
grep -qE '^(sfx|music|narration)/' "$MAN" || { echo "manifest is empty — aborting"; exit 1; }

# Trim without xargs: the prompts contain apostrophes ("a monster's snarl"),
# and xargs treats quotes as syntax — it errors out on every such line.
trim() { local v="$*"; v="${v#"${v%%[![:space:]]*}"}"; printf '%s' "${v%"${v##*[![:space:]]}"}"; }

# Pre-rewritten prompts from reprompt-cache.py. Running the Qwen rewriter inline
# makes ComfyUI swap between it and the audio model on every job — measured at
# 75.6 s/asset on an 8 GB card versus ~8 s without. When the cache exists we use
# it and pass --no-reprompt so the audio pass never loads the LLM at all.
PROMPTS_JSON="$DEST/prompts.json"
cached_prompt() {
    [ -f "$PROMPTS_JSON" ] || return 1
    python3 -c "
import json,sys
try: print(json.load(open(sys.argv[1])).get(sys.argv[2],''))
except Exception: pass" "$PROMPTS_JSON" "$1"
}
[ -f "$PROMPTS_JSON" ] && OGG_ARG="$OGG_ARG --no-reprompt"

want() {
    [ ${#WANT[@]} -eq 0 ] && return 0
    for w in "${WANT[@]}"; do [ "$w" = "$1" ] && return 0; done
    return 1
}
have() {   # any extension the game accepts already present?
    # A tracker-only pack ships no audio, so the score is the deliverable and
    # asking for audio would regenerate every track on every run.
    if [ -n "$MUSIC_TRACKER_ONLY" ] && [ "$SECTION" = music ] && [ -n "$MUSIC_TRACKER" ]; then
        [ -f "$DEST/$1.$MUSIC_TRACKER" ] && return 0
        return 1
    fi
    for e in ogg mp3 wav flac; do [ -f "$DEST/$1.$e" ] && return 0; done
    return 1
}

# --- build the work list -------------------------------------------------
total=0; skipped=0
# The manifest carries a LENGTH column for sfx and music now:
#   sfx/move   | 0.12         | ...   -> a hard max in seconds
#   music/foo  | 30-60s loop  | ...   -> a range; take the upper bound
#   narration/x| text                 -> two fields, no length
while IFS='|' read -r path f2 f3; do
    path="$(trim "$path")"
    case "$path" in "$SECTION"/*) ;; *) continue;; esac
    name="${path#"$SECTION"/}"
    [ -z "$name" ] && continue
    if [ "$SECTION" = narration ]; then
        length=""; prompt="$(trim "$f2")"
    else
        length="$(trim "$f2")"; prompt="$(trim "$f3")"
    fi
    [ -z "$prompt" ] && continue
    want "$name" || continue
    if [ -z "${FORCE:-}" ] && have "$name"; then skipped=$((skipped+1)); continue; fi
    printf '%s|%s|%s\n' "$name" "$length" "$prompt" >> "$QUEUE"
    total=$((total+1))
done < <(grep -E "^$SECTION/" "$MAN")

if [ "$total" -eq 0 ]; then
    echo "▶ $SECTION/$PACK: nothing to do ($skipped already present)"
    exit 0
fi
echo "▶ $SECTION/$PACK: $total to generate, $skipped already present"

# --- narration: one batched CPU run (Kokoro loads once, ~1s a line) ------
if [ "$SECTION" = narration ]; then
    awk -F'|' 'BEGIN{OFS=" | "} {print $1, $3}' "$QUEUE" > "$QUEUE.lines"
    if [ "$NARR_MODE" = "blip" ]; then
        echo "  blip/$BLIP_STYLE  $BLIP_WAVE  ${BLIP_RATE}ch/s  pitch $BLIP_PITCH  (CPU, no farm)"
    else
        echo "  voice $VOICE  pitch $PITCH  speed $SPEED  (CPU, no farm)"
    fi
    if [ "$NARR_MODE" = "blip" ]; then
        soundmon --blip --blip-file "$QUEUE.lines" --blip-style "$BLIP_STYLE" \
                 --blip-wave "$BLIP_WAVE" --blip-rate "$BLIP_RATE" \
                 --blip-pitch "$BLIP_PITCH" --blip-jitter "$BLIP_JITTER" \
                 --voice "$VOICE" $OGG_ARG --output-to "$DEST" --create-dirs
    else
        soundmon --narrate-file "$QUEUE.lines" --voice "$VOICE" --pitch "$PITCH" \
                 --speed "$SPEED" $OGG_ARG --output-to "$DEST" --create-dirs
    fi
    # narrate.py writes <key>.wav next to <key>.ogg under --keep-wav; this
    # branch returns before run_box's masters/ move, so do it here. Narration
    # resolves .ogg first so a stray wav does not break playback, but it doubles
    # the pack size and ships files nobody asked for.
    if [ -n "${KEEPWAV:-}" ]; then
        mkdir -p "$DEST/masters"
        find "$DEST" -maxdepth 1 -name '*.wav' -exec mv -f {} "$DEST/masters/" \;
    fi
    echo "▶ done — $(find "$DEST" -maxdepth 1 \( -name '*.ogg' -o -name '*.wav' -o -name '*.flac' \) | wc -l) file(s) in $DEST"
    exit 0
fi

# --- sfx / music: fan across the farm, DYNAMIC dispatch -----------------
IFS=',' read -ra POOL <<< "$BOXES"
take() { ( flock 9; head -n 1 "$QUEUE"; sed -i '1d' "$QUEUE" ) 9>"$LOCK"; }

run_box() {
    local srv="$1" job name prompt made t0 ext fails=0
    while :; do
        # Drop a box after 3 consecutive failures. Dynamic dispatch hands work to
        # whoever is free, and a box that fails INSTANTLY is always free — so a
        # broken box pulls jobs faster than healthy boxes finish them and eats
        # the whole queue. Observed: one unresponsive box claimed and failed 30
        # of 46 jobs while three working boxes shared the rest.
        if [ "$fails" -ge 3 ]; then
            echo "   ⛔ ${srv%%:*} dropped after 3 consecutive failures"
            break
        fi
        job="$(take)"; [ -z "$job" ] && break
        name="$(printf '%s' "$job" | cut -d'|' -f1)"
        length="$(printf '%s' "$job" | cut -d'|' -f2)"
        prompt="$(printf '%s' "$job" | cut -d'|' -f3-)"
        [ -n "$PROMPT_ADD" ] && prompt="$prompt, $PROMPT_ADD"
        t0=$SECONDS
        if [ "$SECTION" = music ]; then
            # Stable Audio 3 via --music, NOT ACE via --song.
            #
            # ACE is a SONG model: it sings, and it takes bpm/key as real
            # conditioning. But the manifest never asks for vocals — every music
            # prompt says "seamless loop" — and ACE's audio VAE hard-cuts at
            # 16 kHz, which is the hollow "missing frequencies" artifact. SA3 is
            # full-band to 22 kHz (Nyquist at 44.1k) and generates a 60s loop in
            # 3-10s instead of 200-500s.
            #
            # SA3 has no bpm/key inputs, so those move into the PROMPT text.
            # Losing them as hard conditioning is worth full bandwidth and a
            # 20-50x speedup for instrumental game loops.
            local bpm key secs mood
            bpm="$(awk -F'|' -v n="$name" '$1 ~ n {gsub(/ /,"",$3); print $3; exit}' "$DEST/tracks.txt" 2>/dev/null)"
            key="$(awk -F'|' -v n="$name" '$1 ~ n {gsub(/^ +| +$/,"",$4); print $4; exit}' "$DEST/tracks.txt" 2>/dev/null)"
            # Optional 5th column: mood. Inference from the description is good
            # but not always right -- "a memorial to triumphant champions" reads
            # as triumphant when it wants to be solemn. This is where you
            # disagree with it, per track, without touching the manifest.
            mood="$(awk -F'|' -v n="$name" '$1 ~ n {gsub(/^ +| +$/,"",$5); print $5; exit}' "$DEST/tracks.txt" 2>/dev/null)"
            # "30-60s loop" -> 60 ; "3s one-shot" -> 3 ; anything else -> pack default
            secs="$(printf '%s' "$length" | grep -oE '[0-9]+' | tail -1)"
            secs="${secs:-${SECONDS_DEF:-60}}"
            # Stable Audio 3's own system prompt mandates this tail:
            #   "Genre/Style with instruments ... BPM: X. Length: Y seconds"
            # Without it the result is technically clean but musically weaker —
            # identical audio quality, worse composition. Both numbers are
            # already known here, so there is no reason to omit them.
            local musicprompt="$prompt"
            [ -n "$key" ] && musicprompt="$musicprompt, in $key"
            musicprompt="$musicprompt. BPM: ${bpm:-120}. Length: ${secs} seconds"
            local SMOUT; SMOUT="$(mktemp /tmp/smout.$$.XXXXXX)"
        local cp; cp="$(cached_prompt "$name")"
            [ -n "$cp" ] && musicprompt="$cp"
            # Loop-aware post-processing, driven by the manifest's own label.
            # The model COMPOSES AN ENDING -- a 60s request gets a 60s piece of
            # music with a decay -- so a track that plays continuously has a
            # hole at the seam no matter what the endpoints are set to. Leaving
            # them alone makes it worse, not better (measured: tail -30.4 dB
            # trimmed vs -66.4 dB untrimmed). --loop crossfades the tail over
            # the head so the seam is contiguous by construction. Costs 2s.
            local loopargs=""
            case "$length" in
                *loop*) loopargs="--loop" ;;   # "3s one-shot" never matches
            esac
            if [ "$MUSIC_ENGINE" = chip ] || [ "$MUSIC_ENGINE" = opl ]; then
                # Real chip synthesis. No model, no GPU, no server -- and bpm/key
                # become HARD conditioning instead of words in a prompt, because
                # these engines actually compose in a key at a tempo. The rewritten
                # SA3 prompt is irrelevant here and deliberately unused; only the
                # musical parameters matter.
                #
                # Also no $loopargs: both engines compose in whole bars and already
                # loop sample-accurately (verified: seam step smaller than the
                # worst step inside the track). soundmon ignores --loop for them.
                # Transcribe from a reference pack when asked and the file exists.
                local ref=""
                if [ -n "$MUSIC_SOURCE" ]; then
                    for cand in "$ASSETS/music/$MUSIC_SOURCE/$name.ogg" \
                                "$ASSETS/music/$MUSIC_SOURCE/$name.wav"; do
                        [ -f "$cand" ] && { ref="$cand"; break; }
                    done
                    [ -z "$ref" ] && echo "   ⚠ no reference for $name in $MUSIC_SOURCE — composing"
                fi
                local trk=""
                case "$MUSIC_TRACKER" in
                    mod) trk="--write-mod" ;;
                    rad) trk="--write-rad" ;;
                esac
                soundmon "$prompt" "--$MUSIC_ENGINE" --seconds "$secs" \
                         --bpm "${bpm:-120}" --key "${key:-C minor}" \
                         ${mood:+--mood "$mood"} ${ref:+--from-audio "$ref"} \
                         ${trk} ${MUSIC_CHIPPY:+--chippy "$MUSIC_CHIPPY"} \
                         --name "$name" $(music_fmt_arg) \
                         --output-to "$DEST" --no-open >"$SMOUT" 2>&1
            else
                soundmon "$musicprompt" --music --seconds "$secs" $loopargs \
                         --name "$name" --server "$srv" $(music_fmt_arg) \
                         --output-to "$DEST" --no-open >"$SMOUT" 2>&1
            fi
        else
            # Generate with headroom, then hard-cap. The model needs a couple of
            # seconds of canvas to produce a convincing event; asking it for
            # 0.12s directly yields a fragment. --max-seconds truncates after
            # trimming, so what survives is the front of a real sound.
            cap=""
            case "$length" in
                ''|*[!0-9.]*) : ;;
                *) cap="--max-seconds $length" ;;
            esac
            # SA3's SFX system prompt: "Always append: Length: X seconds
            # (integer only, no decimals)."
            local sfxsecs="${SECONDS_DEF:-3}"
            local sfxtext="$prompt. Length: ${sfxsecs%.*} seconds"
            local SMOUT; SMOUT="$(mktemp /tmp/smout.$$.XXXXXX)"
        local cp; cp="$(cached_prompt "$name")"
            [ -n "$cp" ] && sfxtext="$cp"
            if [ "$SFX_ENGINE" = chip ] || [ "$SFX_ENGINE" = opl ]; then
                # Synthesized effect. The ARCHETYPE is inferred from the manifest
                # key ("door" -> creak, "boom" -> explosion), so the game's own
                # naming drives the sound design and there is no prompt at all.
                # $cap carries the manifest's target length, which for an effect
                # is the real duration rather than a ceiling.
                local fxflag="--chipfx"
                [ "$SFX_ENGINE" = opl ] && fxflag="--oplfx"
                soundmon "$prompt" $fxflag --seconds "$sfxsecs" \
                         $cap --name "$name" $OGG_ARG \
                         --output-to "$DEST" --no-open >"$SMOUT" 2>&1
            else
                soundmon "$sfxtext" ${STYLE:+--style "$STYLE"} \
                         --seconds "$sfxsecs" \
                         $cap --name "$name" --server "$srv" $OGG_ARG \
                         --output-to "$DEST" --no-open >"$SMOUT" 2>&1
            fi
        fi
        # soundmon names files <name>_<...>_00001_.<ext>; the game wants <name>.<ext>
        # Prefer the ogg when both exist (--keep-wav leaves a sibling wav).
        # Search EVERY delivery extension, best first. This looked only for .ogg
        # and .wav; a .flac build would have reported "nothing produced" for files
        # sitting right there -- the same failure a bare <name>.wav caused before.
        made=""
        for _e in flac ogg wav; do
            made="$(find "$DEST" -maxdepth 1 -name "${name}_*.$_e" -printf '%T@ %p\n' \
                    | sort -rn | head -1 | cut -d' ' -f2-)"
            [ -n "$made" ] && break
        done
        if [ -n "$made" ]; then
            ext="${made##*.}"
            mv -f "$made" "$DEST/${name}.${ext}"
            if [ -n "${KEEPWAV:-}" ]; then
                mkdir -p "$DEST/masters"
                local keep
                keep="$(find "$DEST" -maxdepth 1 -name "${name}_*.wav" | head -1)"
                [ -n "$keep" ] && mv -f "$keep" "$DEST/masters/${name}.wav"
            fi
            find "$DEST" -maxdepth 1 \( -name "${name}_*.ogg" -o -name "${name}_*.wav" \
                 -o -name "${name}_*.flac" \) -delete
            # DO NOT DELETE OTHER FORMATS. grymmjack keeps the .ogg: they are the
            # takes he has already accepted, and for the SA3 packs they are
            # irreplaceable — no seed was ever recorded for them, so a deleted ogg
            # is a take that can never be reproduced. An earlier version of this
            # removed the sibling automatically, "to stop a stale twin outranking
            # the new file", which is a real hazard but not one worth paying for
            # with someone else's masters.
            #
            # CONSEQUENCE TO KNOW: a pack may now hold both <name>.ogg and
            # <name>.flac, and the game resolves whichever extension it looks for
            # first. If it prefers .ogg you will still hear the old take. Move the
            # oggs aside (see ~/old-soundmon-oggs) rather than delete them when you
            # want the flac to win.
            :
            # Tracker scores get the same treatment as the audio: keep the newest,
            # name it after the manifest key, drop the rest. Without this every
            # regeneration left another <name>_s<seed>.mod behind, and after a few
            # runs it is no longer obvious which score matches the render.
            for _t in mod rad; do
                _new="$(find "$DEST" -maxdepth 1 -name "${name}_*.$_t" \
                        -printf '%T@ %p\n' | sort -rn | head -1 | cut -d' ' -f2-)"
                [ -n "$_new" ] && mv -f "$_new" "$DEST/${name}.$_t"
                find "$DEST" -maxdepth 1 -name "${name}_*.$_t" -delete
            done
            # Score-only pack: the audio was a means to an end. Remove it ONLY
            # once the score is confirmed on disk -- never before, or a failed
            # write would leave the track with nothing at all.
            if [ -n "$MUSIC_TRACKER_ONLY" ] && [ "$SECTION" = music ] \
               && [ -n "$MUSIC_TRACKER" ] && [ -f "$DEST/${name}.$MUSIC_TRACKER" ]; then
                rm -f "$DEST/${name}.${ext}"
                echo "   ♫ ${name}.$MUSIC_TRACKER  (score only; audio dropped)"
            fi
            # Append, never rewrite: jobs run concurrently across boxes and a
            # short append is atomic, where a read-modify-write of one JSON file
            # would lose entries under parallelism.
            _seed="$(grep -oE 'seed=[0-9]+' "$SMOUT" 2>/dev/null | head -1 | cut -d= -f2)"
            [ -n "$_seed" ] && printf '%s\t%s\n' "$name" "$_seed" >> "$SEEDS_TSV"
            echo "   ✅ ${srv%%:*}  ${name}.${ext}  ($((SECONDS - t0))s)${_seed:+  seed=$_seed}"
            fails=0
        else
            # Put it back for a healthy box to pick up, rather than losing it.
            printf '%s|%s\n' "$name" "${job#*|}" >> "$QUEUE"
            fails=$((fails + 1))
            echo "   ❌ ${srv%%:*}  ${name}  (nothing produced; requeued)"
        fi
    done
}

for srv in "${POOL[@]}"; do run_box "$srv" & done
wait
# Fold the append-only ledger into seeds.json. Last write per asset wins, which
# is what you want: a regenerated asset should record the seed it now HAS.
if [ -s "$SEEDS_TSV" ]; then
    python3 - "$SEEDS_TSV" "$SEEDS_JSON" <<'PYEOF'
import json, os, sys
tsv, out = sys.argv[1], sys.argv[2]
seeds = {}
if os.path.exists(out):
    try: seeds = json.load(open(out))
    except Exception: seeds = {}
for line in open(tsv):
    parts = line.rstrip("\n").split("\t")
    if len(parts) == 2 and parts[1].isdigit():
        seeds[parts[0]] = int(parts[1])
json.dump(dict(sorted(seeds.items())), open(out, "w"), indent=1)
print(f"   \u266b seeds.json: {len(seeds)} asset(s) reproducible")
PYEOF
    rm -f "$SEEDS_TSV"
fi
echo "▶ done — $(find "$DEST" -maxdepth 1 \( -name '*.ogg' -o -name '*.wav' -o -name '*.flac' \) | wc -l) file(s) in $DEST"

#!/usr/bin/env bash
# Make a COMPLETE audio pack — sfx + music + narration — from one theme phrase.
#
#   ./make-pack.sh "like dark souls"
#   ./make-pack.sh souls --name soundmon-souls
#   ./make-pack.sh "vaporwave temple" --only sfx,music
#   ./make-pack.sh souls --sfx /tmp/s --music /tmp/m --narration /tmp/n
#
# Everything the game asks for, in one command, as OGG. The asset list and the
# per-asset prompts come from `dungeon.run audiomanifest` (the game's own
# contract); the THEME supplies the treatment — how it should sound, and in
# whose voice. Those are the two independent axes, so they stay separate:
# the manifest says WHAT, the theme says HOW.
#
# Themes live in assets/themes/*.theme and are matched loosely, so "like dark
# souls" finds souls.theme. An unknown phrase still works — it's used verbatim
# as the treatment — so you are never blocked on authoring a theme file first.
#
# OPTIONS
#   --name NAME        pack folder name           [soundmon-<theme>]
#   --sfx DIR          sfx output dir             [assets/sfx/<name>]
#   --music DIR        music output dir           [assets/music/<name>]
#   --narration DIR    narration output dir       [assets/narration/<name>]
#   --only a,b         sections to build          [sfx,music,narration]
#   --boxes a,b        render farm boxes          [local,mac,rtx]
#   --voice V          override the theme's voice
#   --flac             lossless FLAC  [default]
#   --ogg              lossy OGG Vorbis
#   --wav              uncompressed WAV
#   --force            regenerate assets that already exist
#   --list             list available themes and exit
set -uo pipefail

ASSETS="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
THEMES="$ASSETS/themes"

if [ "${1:-}" = "--list" ]; then
    echo "Available themes (assets/themes/*.theme):"
    for t in "$THEMES"/*.theme; do
        [ -f "$t" ] || continue
        n="$(basename "$t" .theme)"
        m="$(grep -m1 '^MATCH=' "$t" | cut -d'"' -f2)"
        printf "  %-14s matches: %s\n" "$n" "$m"
    done
    echo
    echo 'Any other phrase works too — it is used verbatim as the treatment.'
    exit 0
fi

PHRASE="${1:?usage: $0 \"<theme phrase>\" [options]   ($0 --list)}"
shift

NAME=""; ONLY="sfx,music,narration"; BOXES_ARG=""; VOICE_OVERRIDE=""
OUT_SFX=""; OUT_MUSIC=""; OUT_NARR=""; FMT=flac; FORCE_ARG=""
while [ $# -gt 0 ]; do
    case "$1" in
        --name)      NAME="$2"; shift 2;;
        --sfx)       OUT_SFX="$2"; shift 2;;
        --music)     OUT_MUSIC="$2"; shift 2;;
        --narration) OUT_NARR="$2"; shift 2;;
        --only)      ONLY="$2"; shift 2;;
        --boxes)     BOXES_ARG="$2"; shift 2;;
        --voice)     VOICE_OVERRIDE="$2"; shift 2;;
        --wav)       FMT=wav; shift;;
        --ogg)       FMT=ogg; shift;;
        --flac)      FMT=flac; shift;;
        --force)     FORCE_ARG=1; shift;;
        *) echo "unknown option: $1"; exit 1;;
    esac
done

# --- resolve the theme ---------------------------------------------------
# Loose match so natural phrasing works: strip everything but letters, then look
# for any MATCH keyword inside it. "like dark souls" -> likedarksouls -> souls.
norm="$(printf '%s' "$PHRASE" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]')"
THEME_FILE=""; THEME_NAME=""
for t in "$THEMES"/*.theme; do
    [ -f "$t" ] || continue
    n="$(basename "$t" .theme)"
    for kw in $n $(grep -m1 '^MATCH=' "$t" | cut -d'"' -f2); do
        k="$(printf '%s' "$kw" | tr -cd '[:alnum:]')"
        [ -n "$k" ] && case "$norm" in *"$k"*) THEME_FILE="$t"; THEME_NAME="$n"; break 2;; esac
    done
done

# Theme defaults, then the file overrides them.
SFX_ADD=""; MUSIC_ADD=""; SFX_SECONDS=3; MUSIC_SECONDS=60
MUSIC_BPM=""; MUSIC_KEY=""; MUSIC_MOOD=""; VOICE=bm_george; PITCH=-3; SPEED=0.92
# Narration can be spoken (Kokoro) or blipped (JRPG text-box). A chiptune pack
# wants a chiptune voice. Set NARR_MODE=blip in the theme to switch.
SFX_ENGINE=sa3; MUSIC_ENGINE=sa3; MUSIC_SOURCE=
MUSIC_TRACKER=; MUSIC_CHIPPY=; MUSIC_FORMAT=; MUSIC_TRACKER_ONLY=
NARR_MODE=narrate; BLIP_STYLE=synth; BLIP_WAVE=square
BLIP_RATE=14; BLIP_PITCH=0; BLIP_JITTER=1.5
# narration playback fade -- the game ramps every line in from silence at the start and
# out at the end, masking the record key's click. FADEIN/FADEOUT are seconds; FADECURVE
# shapes the ramp (<1 sharp/fast rise, 1 linear, >1 gentle). Defaults match the engine.
NARR_FADEIN=0.25; NARR_FADEOUT=0.5; NARR_FADECURVE=0.5
if [ -n "$THEME_FILE" ]; then
    . "$THEME_FILE"
    echo "▶ theme: $THEME_NAME   (matched \"$PHRASE\")"
else
    # No theme file — use the phrase itself as the treatment. Strip a leading
    # "like " so 'like dark souls' reads naturally inside a prompt.
    p="$(printf '%s' "$PHRASE" | sed 's/^[[:space:]]*[Ll]ike[[:space:]]\+//')"
    SFX_ADD="$p, high quality game audio"
    MUSIC_ADD="$p"
    THEME_NAME="$(printf '%s' "$p" | tr '[:upper:] ' '[:lower:]-' | tr -cd '[:alnum:]-')"
    echo "▶ theme: (none registered) — using \"$p\" verbatim"
    echo "  add $THEMES/$THEME_NAME.theme to make this reusable"
fi
[ -n "$VOICE_OVERRIDE" ] && VOICE="$VOICE_OVERRIDE"

NAME="${NAME:-soundmon-$THEME_NAME}"
OUT_SFX="${OUT_SFX:-$ASSETS/sfx/$NAME}"
OUT_MUSIC="${OUT_MUSIC:-$ASSETS/music/$NAME}"
OUT_NARR="${OUT_NARR:-$ASSETS/narration/$NAME}"

echo "  pack:  $NAME"
if [ "$NARR_MODE" = blip ]; then
  echo "  voice: blip/$BLIP_STYLE ($BLIP_WAVE, ${BLIP_RATE}ch/s, pitch $BLIP_PITCH)"
else
  echo "  voice: $VOICE (pitch $PITCH, speed $SPEED)"
fi
echo "  out:   $OUT_SFX"
echo "         $OUT_MUSIC"
echo "         $OUT_NARR"
echo "  format: $(echo "$FMT" | tr a-z A-Z)"

# --- write each section's pack.conf, then hand off to the generator -------
# generate-from-manifest.sh already knows how to talk to the farm, skip what
# exists, and rename outputs to the manifest key. It reads <dest>/pack.conf for
# identity, so a theme is just three small conf files plus three invocations.
want() { case ",$ONLY," in *",$1,"*) return 0;; esac; return 1; }
# FLAC by default -- lossless, and close to OGG in size for this material.
export FORMAT="$FMT"
[ -n "$FORCE_ARG" ] && export FORCE=1
[ -n "$BOXES_ARG" ] && export BOXES="$BOXES_ARG"

# Snapshot the manifest once. Every section then works from the same bytes,
# so a rebuild of dungeon.run partway through cannot change or empty it.
SNAP="$(mktemp)"; trap 'rm -f "$SNAP"' EXIT
( cd "$(dirname "$ASSETS")" && ./dungeon.run audiomanifest ) > "$SNAP" 2>/dev/null
if ! grep -qE '^(sfx|music|narration)/' "$SNAP"; then
    echo "✗ could not read a manifest from dungeon.run — build it (F5) and retry"
    exit 1
fi
export MANIFEST="$SNAP"
echo "  manifest: $(grep -cE '^(sfx|music|narration)/' "$SNAP") entries (snapshotted)"

rc=0
if want sfx; then
    mkdir -p "$OUT_SFX"
    { echo "# generated by make-pack.sh from theme: $THEME_NAME"
      echo "PROMPT_ADD=\"$SFX_ADD\""
      echo "SFX_ENGINE=$SFX_ENGINE"
      echo "SECONDS_DEF=$SFX_SECONDS"; } > "$OUT_SFX/pack.conf"
    echo; echo "═══ SFX ═══"
    "$ASSETS/generate-from-manifest.sh" sfx "$(basename "$OUT_SFX")" || rc=1
fi

if want music; then
    mkdir -p "$OUT_MUSIC"
    { echo "# generated by make-pack.sh from theme: $THEME_NAME"
      echo "PROMPT_ADD=\"$MUSIC_ADD\""
      echo "MUSIC_ENGINE=$MUSIC_ENGINE"
      echo "MUSIC_SOURCE=$MUSIC_SOURCE"
      echo "MUSIC_TRACKER=$MUSIC_TRACKER"
      echo "MUSIC_TRACKER_ONLY=$MUSIC_TRACKER_ONLY"
      echo "MUSIC_CHIPPY=$MUSIC_CHIPPY"
      echo "MUSIC_FORMAT=$MUSIC_FORMAT"
      echo "SECONDS_DEF=$MUSIC_SECONDS"; } > "$OUT_MUSIC/pack.conf"
    # tracks.txt gives the generator per-track bpm/key. A theme supplies one
    # tempo/key for the whole pack unless a hand-written tracks.txt is already
    # there, which we never overwrite.
    if [ -n "$MUSIC_BPM$MUSIC_KEY" ] && [ ! -f "$OUT_MUSIC/tracks.txt" ]; then
        echo "# name | seconds | bpm | key | mood  -- theme defaults, edit freely" > "$OUT_MUSIC/tracks.txt"
        echo "# mood is OPTIONAL: blank means infer it from the manifest description." >> "$OUT_MUSIC/tracks.txt"
        echo "# soundmon --list-moods shows the set." >> "$OUT_MUSIC/tracks.txt"
        while read -r n; do
            printf '%s | %s | %s | %s | %s\n' "$n" "$MUSIC_SECONDS" "$MUSIC_BPM" "$MUSIC_KEY" "$MUSIC_MOOD" >> "$OUT_MUSIC/tracks.txt"
        done < <(sed -n 's|^music/\([^ |]*\).*|\1|p' "$SNAP" | sort -u)
    fi
    echo; echo "═══ MUSIC ═══"
    "$ASSETS/generate-from-manifest.sh" music "$(basename "$OUT_MUSIC")" || rc=1
fi

if want narration; then
    mkdir -p "$OUT_NARR"
    { echo "# generated by make-pack.sh from theme: $THEME_NAME"
      echo "VOICE=$VOICE"; echo "PITCH=$PITCH"; echo "SPEED=$SPEED"
      echo "NARR_MODE=$NARR_MODE"; echo "BLIP_STYLE=$BLIP_STYLE"
      echo "BLIP_WAVE=$BLIP_WAVE"; echo "BLIP_RATE=$BLIP_RATE"
      echo "BLIP_PITCH=$BLIP_PITCH"; echo "BLIP_JITTER=$BLIP_JITTER"
      echo "FADEIN=$NARR_FADEIN"; echo "FADEOUT=$NARR_FADEOUT"; echo "FADECURVE=$NARR_FADECURVE"; } > "$OUT_NARR/pack.conf"
    echo; echo "═══ NARRATION ═══"
    "$ASSETS/generate-from-manifest.sh" narration "$(basename "$OUT_NARR")" || rc=1
fi

echo
if [ "$rc" -eq 0 ]; then echo "▶ pack '$NAME' complete"
else echo "✗ pack '$NAME' INCOMPLETE — a section failed above"; fi
for d in "$OUT_SFX" "$OUT_MUSIC" "$OUT_NARR"; do
    [ -d "$d" ] && printf "   %-52s %3s files  %s\n" "$d" \
        "$(find "$d" -maxdepth 1 \( -name '*.ogg' -o -name '*.wav' \) 2>/dev/null | wc -l)" \
        "$(du -sh "$d" 2>/dev/null | cut -f1)"
done
exit $rc

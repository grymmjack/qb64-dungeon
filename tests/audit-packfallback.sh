#!/usr/bin/env bash
# Every content-pack resolver must fall back to the DEFAULT pack, PER FILE.
#
# The pack model is: a pack is a named subfolder, and a PARTIAL pack overrides only the files
# it actually ships -- everything else comes from `default/`. That promise lives in six
# separate resolvers, one per asset type, and each is a couple of lines. Nothing about a
# missing fallback is loud: the game just plays silently, or a sprite is blank, or a monster
# has no portrait -- in the exact situation (a partial third-party pack) the maintainer is
# least likely to be testing.
#
# So this asserts the STRUCTURE rather than the behaviour: each resolver must (a) try the
# selected pack and (b) name `default/` as a fallback. That covers the resolvers that cannot
# be unit-tested headlessly (RegisterSfx opens a real sound device) at the cost of being a
# grep -- which is the same trade the other audits in this directory make.
#
# Usage: tests/audit-packfallback.sh          (run from anywhere)

set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

fail=0

# file | routine | asset type | the default-pack path fragment it must name
CHECKS=(
  "engine/ARTPACK.bas|PixelArtFile\$|pixel art|assets/pixel-art/default/"
  "engine/ARTPACK.bas|AnsiArtFile\$|ansi art|assets/ansi-art/default/"
  "engine/ARTPACK.bas|AnsiFile\$|ANSI art|assets/ansi-art/default/"
  "engine/MUSIC.bas|RegisterSfx|sound effects|assets/sfx/default/"
  "engine/MUSIC.bas|ResolveMusic\$|music|assets/music/default/"
  "engine/MUSIC.bas|NarratePath\$|narration|assets/narration/default/"
  "engine/MUSIC.bas|LoadNarrConf|narration pack.conf|assets/narration/default/"
  "engine/DATA.bas|DataPath\$|data + flavor tables|default/"
)

# Print the body of SUB/FUNCTION <name> from <file>.
# Matched LITERALLY, not by regex: these names end in `$` (ArtFile$, DataPath$), and in a
# regex that `$` is an end-of-line anchor -- so a regex match silently finds nothing and the
# audit reports every resolver as "not found" instead of checking it.
routine_body() {
    local file="$1" name="$2"
    awk -v want="$(printf '%s' "$name" | tr '[:lower:]' '[:upper:]')" '
        BEGIN { inr = 0 }
        {
            up = toupper($0)
            sub(/^ +/, "", up)
            hit = 0
            if (index(up, "SUB " want) == 1 || index(up, "FUNCTION " want) == 1) {
                # require a word boundary after the name so DataPath$ != DataPathExtra$
                rest = substr(up, index(up, want) + length(want), 1)
                if (rest == "" || rest == " " || rest == "(") hit = 1
            }
            if (inr == 0 && hit) { inr = 1 }
            else if (inr && (up ~ /^END SUB/ || up ~ /^END FUNCTION/)) { print; inr = 0 }
            if (inr) print
        }
    ' "$file"
}

for spec in "${CHECKS[@]}"; do
    IFS='|' read -r file routine kind want <<<"$spec"
    body=$(routine_body "$file" "$routine")
    if [[ -z "$body" ]]; then
        printf '  !! %-22s not found in %s (renamed? then update this audit)\n' "$routine" "$file"
        fail=$((fail + 1))
        continue
    fi
    # (a) does it consult the selected pack at all?
    if ! grep -qiE 'opt_(artpack|ansipack|sfxpack|musicpack|narrationpack|datapack)' <<<"$body"; then
        printf '  !! %-22s (%s) never consults the selected pack\n' "$routine" "$kind"
        fail=$((fail + 1))
    fi
    # (b) does it name the default pack as a fallback?
    if ! grep -qF "$want" <<<"$body"; then
        printf '  !! %-22s (%s) has NO fallback to %s\n' "$routine" "$kind" "$want"
        printf '     a partial %s pack would come up EMPTY instead of using the default pack.\n' "$kind"
        fail=$((fail + 1))
    fi
done

if (( fail )); then
    echo "$fail pack-fallback problem(s) -- a partial pack would not degrade to default/."
    exit 1
fi
echo "all ${#CHECKS[@]} content-pack resolvers fall back to default/ per file."
exit 0

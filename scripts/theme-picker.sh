#!/usr/bin/env bash
# Gentoo-rice – Theme-Auswahl (Super+Shift+T): Leiste mit Farbvorschau
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
REPO="$(dirname "$DIR")"
STATE="$HOME/.cache/rice"
SW="$STATE/theme-swatches"
mkdir -p "$SW"

pkill -x rofi 2>/dev/null && exit 0

current=$("$DIR/theme.sh" current)
NAMES=() LABELS=() ICONS=()

swatch() { # swatch <name> → Vorschaubild 400x225
    local n=$1 file="$REPO/themes/$1/theme.conf" out x i
    out="$SW/$n-$(stat -c %Y "$file").png"
    [[ -s $out ]] && { echo "$out"; return; }
    (
        # shellcheck source=/dev/null
        source "$file"
        if [[ ${MODE:-dynamic} == dynamic ]]; then
            if [[ -f $STATE/current.png ]]; then
                magick "$STATE/current.png" -resize 400x225^ -gravity center -extent 400x225 \
                    -gravity northwest -fill '#000000b4' -draw 'roundrectangle 12,12,96,40,8,8' \
                    -fill white -pointsize 16 -annotate +26+17 'AUTO' "$out"
            else
                magick -size 400x225 gradient:'#2a1f3d'-'#16131f' "$out"
            fi
        else
            read -ra P <<<"$PALETTE"
            args=(-size 400x225 xc:"$BG" -fill "${P[4]}" -draw "roundrectangle 24,24,376,92,14,14")
            x=24
            for i in 1 2 3 5 6 13; do
                args+=(-fill "${P[$i]}" -draw "circle $((x + 22)),160 $((x + 22)),136")
                x=$((x + 60))
            done
            args+=(-fill "$FG" -draw "rectangle 24,206 376,212")
            magick "${args[@]}" "$out"
        fi
    ) 2>/dev/null || true
    echo "$out"
}

while IFS=$'\t' read -r n _mode desc; do
    NAMES+=("$n")
    if [[ $n == "$current" ]]; then LABELS+=("● $n"); else LABELS+=("$n"); fi
    ICONS+=("$(swatch "$n")")
    : "$desc"
done < <("$DIR/theme.sh" list)

idx=$(for i in "${!NAMES[@]}"; do printf '%s\0icon\x1f%s\n' "${LABELS[$i]}" "${ICONS[$i]}"; done |
    rofi -dmenu -i -show-icons -format i -p "Theme" -theme "$HOME/.config/rofi/wallpaper.rasi") || exit 0
[[ -n $idx ]] && "$DIR/theme.sh" set "${NAMES[$idx]}"

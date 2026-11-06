#!/usr/bin/env bash
# Gentoo-rice – Wallpaper-Picker (Super+W): horizontale Leiste mit Vorschaubildern
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"

DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
WALLDIR="${RICE_WALLDIR:-$HOME/Pictures/wallpapers}"
THUMBS="$HOME/.cache/rice/thumbs"
mkdir -p "$THUMBS"

pkill -x rofi 2>/dev/null && exit 0

is_video() { [[ ${1,,} =~ \.(mp4|mkv|webm|mov|avi|m4v)$ ]]; }
mapfile -t FILES < <(find -L "$WALLDIR" -maxdepth 2 -type f \( -iname '*.jpg' -o -iname '*.jpeg' \
    -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.mp4' -o -iname '*.mkv' \
    -o -iname '*.webm' -o -iname '*.mov' -o -iname '*.avi' -o -iname '*.m4v' \) 2>/dev/null | sort)

if ((${#FILES[@]} == 0)); then
    notify-send -a Wallpaper "Keine Wallpaper" "Bilder/Videos nach $WALLDIR legen" 2>/dev/null || true
    exit 0
fi

thumb() { # thumb <datei>  → Pfad zum gecachten Vorschaubild
    local f=$1 key t vf="scale=400:225:force_original_aspect_ratio=increase,crop=400:225"
    key=$(printf '%s|%s' "$f" "$(stat -c %Y "$f")" | md5sum | cut -c1-20)
    t="$THUMBS/$key.png"
    if [[ ! -s $t ]]; then
        if is_video "$f"; then
            ffmpeg -y -loglevel error -ss 1 -i "$f" -frames:v 1 -vf "$vf" "$t" 2>/dev/null ||
                ffmpeg -y -loglevel error -i "$f" -frames:v 1 -vf "$vf" "$t" 2>/dev/null || true
            # VIDEO-Badge
            [[ -s $t ]] && magick "$t" -fill '#000000b4' -draw 'roundrectangle 12,12,96,40,8,8' \
                -fill white -pointsize 16 -annotate +22+33 'VIDEO' "$t" 2>/dev/null || true
        else
            ffmpeg -y -loglevel error -i "$f" -frames:v 1 -vf "$vf" "$t" 2>/dev/null ||
                magick "${f}[0]" -resize 400x225^ -gravity center -extent 400x225 "$t" 2>/dev/null || true
        fi
    fi
    echo "$t"
}

missing=0
for f in "${FILES[@]}"; do
    key=$(printf '%s|%s' "$f" "$(stat -c %Y "$f")" | md5sum | cut -c1-20)
    [[ -s $THUMBS/$key.png ]] || missing=$((missing + 1))
done
((missing > 3)) && notify-send -a Wallpaper "Erzeuge $missing Vorschaubilder …" 2>/dev/null || true

entries() {
    local f name
    for f in "${FILES[@]}"; do
        name=$(basename "${f%.*}")
        is_video "$f" && name="▶ $name"
        printf '%s\0icon\x1f%s\n' "$name" "$(thumb "$f")"
    done
}

idx=$(entries | rofi -dmenu -i -show-icons -format i -p "" \
    -theme "$HOME/.config/rofi/wallpaper.rasi") || exit 0
[[ -n $idx ]] && "$DIR/wallpaper.sh" set "${FILES[$idx]}"

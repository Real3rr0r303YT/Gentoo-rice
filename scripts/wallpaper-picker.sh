#!/usr/bin/env bash
# Gentoo-rice – Wallpaper-Picker (Super+W): horizontale Leiste mit Vorschaubildern
# Bilder/Videos aus ~/Pictures/wallpapers + Wallpaper-Engine-Workshop-Wallpaper (Badge "WE")
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"

DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=scripts/we-lib.sh
source "$DIR/we-lib.sh"
WALLDIR="${RICE_WALLDIR:-$HOME/Pictures/wallpapers}"
THUMBS="$HOME/.cache/rice/thumbs"
mkdir -p "$THUMBS"

pkill -x rofi 2>/dev/null && exit 0

is_video() { [[ ${1,,} =~ \.(mp4|mkv|webm|mov|avi|m4v)$ ]]; }

# Einträge: KIND (file|we), TARGET (Pfad/Ordner), LABEL, SOURCE (Bild für Vorschau), BADGE
KIND=() TARGET=() LABEL=() SOURCE=() BADGE=()

while IFS= read -r f; do
    KIND+=(file); TARGET+=("$f"); SOURCE+=("$f")
    if is_video "$f"; then LABEL+=("▶ $(basename "${f%.*}")"); BADGE+=(VIDEO)
    else LABEL+=("$(basename "${f%.*}")"); BADGE+=(""); fi
done < <(find -L "$WALLDIR" -maxdepth 2 -type f \( -iname '*.jpg' -o -iname '*.jpeg' \
    -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.mp4' -o -iname '*.mkv' \
    -o -iname '*.webm' -o -iname '*.mov' -o -iname '*.avi' -o -iname '*.m4v' \) 2>/dev/null | sort)

# Wallpaper Engine: nur scene/video, web als experimentell
we_load_config
while IFS=$'\t' read -r wdir wtype wtitle wprev; do
    [[ -n $wdir ]] || continue
    case $wtype in
        scene|video) lbl="WE · $wtitle" ;;
        web)         lbl="WE · $wtitle (experimentell)" ;;
        *)           continue ;;
    esac
    KIND+=(we); TARGET+=("$wdir"); LABEL+=("$lbl"); SOURCE+=("$wprev"); BADGE+=(WE)
done < <(we_list 2>/dev/null)

if ((${#KIND[@]} == 0)); then
    notify-send -a Wallpaper "Keine Wallpaper" "Bilder/Videos nach $WALLDIR legen" 2>/dev/null || true
    exit 0
fi

thumb_path() { printf '%s/%s.png' "$THUMBS" "$(printf '%s|%s|%s' "$1" "$2" "$(stat -c %Y "$1" 2>/dev/null)" | md5sum | cut -c1-20)"; }

thumb() { # thumb <quelle> <badge>  → Pfad zum gecachten Vorschaubild
    local f=$1 badge=$2 t vf="scale=400:225:force_original_aspect_ratio=increase,crop=400:225"
    [[ -f $f ]] || { echo ""; return; }
    t=$(thumb_path "$f" "$badge")
    if [[ ! -s $t ]]; then
        if is_video "$f"; then
            ffmpeg -y -loglevel error -ss 1 -i "$f" -frames:v 1 -vf "$vf" "$t" 2>/dev/null ||
                ffmpeg -y -loglevel error -i "$f" -frames:v 1 -vf "$vf" "$t" 2>/dev/null || true
        else
            ffmpeg -y -loglevel error -i "$f" -frames:v 1 -vf "$vf" "$t" 2>/dev/null ||
                magick "${f}[0]" -resize 400x225^ -gravity center -extent 400x225 "$t" 2>/dev/null || true
        fi
        if [[ -s $t && -n $badge ]]; then
            local w=$(( ${#badge} * 11 + 22 ))
            magick "$t" -fill '#000000b4' -draw "roundrectangle 12,12,$((12 + w)),40,8,8" \
                -fill white -pointsize 16 -annotate +22+33 "$badge" "$t" 2>/dev/null || true
        fi
    fi
    echo "$t"
}

missing=0
for i in "${!KIND[@]}"; do
    [[ -f ${SOURCE[$i]} && ! -s $(thumb_path "${SOURCE[$i]}" "${BADGE[$i]}") ]] && missing=$((missing + 1))
done
if ((missing > 3)); then notify-send -a Wallpaper "Erzeuge $missing Vorschaubilder …" 2>/dev/null || true; fi

entries() {
    local i
    for i in "${!KIND[@]}"; do
        printf '%s\0icon\x1f%s\n' "${LABEL[$i]}" "$(thumb "${SOURCE[$i]}" "${BADGE[$i]}")"
    done
}

idx=$(entries | rofi -dmenu -i -show-icons -format i -p "" \
    -theme "$HOME/.config/rofi/wallpaper.rasi") || exit 0
[[ -n $idx ]] || exit 0
if [[ ${KIND[$idx]} == we ]]; then
    "$DIR/we-set.sh" "${TARGET[$idx]}"
else
    "$DIR/wallpaper.sh" set "${TARGET[$idx]}"
fi

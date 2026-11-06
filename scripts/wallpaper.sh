#!/usr/bin/env bash
# Gentoo-rice – Wallpaper setzen (Bild: swww/awww, Video: mpvpaper) + Farben via pywal16
# Nutzung: wallpaper.sh set <datei> | random | restore | init [datei] | colors
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"

REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
WALLDIR="${RICE_WALLDIR:-$HOME/Pictures/wallpapers}"
STATE="$HOME/.cache/rice"
WAL="$HOME/.cache/wal"
mkdir -p "$STATE" "$WAL"

is_video() { [[ ${1,,} =~ \.(mp4|mkv|webm|mov|avi|m4v)$ ]]; }
list_walls() {
    find -L "$WALLDIR" -maxdepth 2 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \
        -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.webm' \
        -o -iname '*.mov' -o -iname '*.avi' -o -iname '*.m4v' \) 2>/dev/null | sort
}
notify() { command -v notify-send >/dev/null && notify-send -a Wallpaper "$@" || true; }

# Standbild (für Farben + hyprlock) nach $STATE/current.png
still() {
    local f=$1 out="$STATE/current.png"
    if is_video "$f"; then
        ffmpeg -y -loglevel error -ss 2 -i "$f" -frames:v 1 -vf "scale='min(2560,iw)':-2" "$out" 2>/dev/null ||
            ffmpeg -y -loglevel error -i "$f" -frames:v 1 -vf "scale='min(2560,iw)':-2" "$out"
    else
        ffmpeg -y -loglevel error -i "$f" -frames:v 1 -vf "scale='min(2560,iw)':-2" "$out" 2>/dev/null ||
            magick "${f}[0]" "$out"
    fi
}

# Fallback ohne pywal16: Templates mit festem Schema rendern
fallback_colors() {
    python3 - "$REPO/wal/templates" "$WAL" <<'PY'
import os, sys
src, dst = sys.argv[1], sys.argv[2]
class C(str):
    @property
    def strip(self): return self.lstrip('#')
    @property
    def rgb(self):
        h = self.lstrip('#'); return ','.join(str(int(h[i:i+2], 16)) for i in (0, 2, 4))
pal = ['#16131f','#e0607e','#8fcf9b','#e6c384','#7aa2f7','#bb9af7','#7dcfff','#d8d4e6',
       '#4a4458','#ec7f98','#a6dab0','#edd3a3','#97b6fa','#cbb2f9','#9adbff','#f2f0f8']
d = {f'color{i}': C(c) for i, c in enumerate(pal)}
d.update(background=C(pal[0]), foreground=C(pal[15]), cursor=C(pal[15]), wallpaper='')
for n in os.listdir(src):
    with open(os.path.join(src, n)) as f: t = f.read()
    with open(os.path.join(dst, n), 'w') as f: f.write(t.format(**d))
kitty = ''.join(f'color{i} {c}\n' for i, c in enumerate(pal))
with open(os.path.join(dst, 'colors-kitty.conf'), 'w') as f:
    f.write(f'foreground {pal[15]}\nbackground {pal[0]}\ncursor {pal[15]}\n' + kitty)
PY
}

gen_colors() { # gen_colors [--quiet-terminals]
    if command -v wal >/dev/null; then
        if [[ ${1:-} == --quiet-terminals ]]; then wal -q -n -s -t -e -i "$STATE/current.png" >/dev/null 2>&1 && return 0
        else wal -q -n -t -e -i "$STATE/current.png" >/dev/null 2>&1 && return 0; fi
    fi
    fallback_colors
}

reload_all() {
    [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] || return 0
    hyprctl reload >/dev/null 2>&1 || true
    pkill -USR2 -x waybar 2>/dev/null || true
    if pgrep -x mako >/dev/null; then makoctl reload 2>/dev/null || true
    else (mako -c "$WAL/mako-config" >/dev/null 2>&1 &); fi
    pkill -USR1 -x cava 2>/dev/null || true
    [[ -f $WAL/colors-kitty.conf ]] && for s in /tmp/kitty-*; do
        [[ -S $s ]] && kitty @ --to "unix:$s" set-colors -a -c "$WAL/colors-kitty.conf" >/dev/null 2>&1 || true
    done
}

img_backend() {
    local b
    for b in awww swww; do command -v "$b" >/dev/null && { echo "$b"; return 0; }; done
    return 1
}
ensure_daemon() {
    local b=$1 i
    "$b" query >/dev/null 2>&1 && return 0
    ("$b-daemon" >/dev/null 2>&1 &)
    for i in $(seq 20); do "$b" query >/dev/null 2>&1 && return 0; sleep 0.1; done
}

show() { # Wallpaper anzeigen (nur in einer laufenden Sitzung)
    local f=$1 b
    [[ -n ${WAYLAND_DISPLAY:-} ]] || return 0
    if is_video "$f"; then
        pkill -x mpvpaper 2>/dev/null || true
        (mpvpaper -o "no-audio --loop-file=inf --hwdec=auto --panscan=1.0 --really-quiet" ALL "$f" >/dev/null 2>&1 &)
    else
        pkill -x mpvpaper 2>/dev/null || true
        b=$(img_backend) || { notify "swww/awww fehlt"; return 0; }
        ensure_daemon "$b"
        "$b" img "$f" --transition-type grow --transition-pos 0.5,0.5 \
            --transition-duration 1.4 --transition-fps 60 --transition-bezier .22,1,.36,1 >/dev/null 2>&1 || true
    fi
}

set_wall() { # set_wall <datei> [quiet]
    local f
    f=$(readlink -f "$1") || { echo "Datei nicht gefunden: $1" >&2; exit 1; }
    [[ -f $f ]] || { echo "Datei nicht gefunden: $1" >&2; exit 1; }
    printf '%s\n' "$f" > "$STATE/wallpaper"
    still "$f"
    show "$f"
    gen_colors
    reload_all
    [[ ${2:-} == quiet ]] || notify -i "$STATE/current.png" "Wallpaper" "$(basename "$f")"
}

default_wall() {
    local f
    f=$(list_walls | head -n1)
    [[ -n $f ]] || f=$(ls "$REPO"/wallpapers/*.jpg 2>/dev/null | head -n1)
    echo "$f"
}

case "${1:-}" in
    set)     [[ -n ${2:-} ]] || { echo "Nutzung: $0 set <datei>" >&2; exit 1; }; set_wall "$2" ;;
    random)  f=$(list_walls | shuf -n1); [[ -n $f ]] && set_wall "$f" ;;
    restore) f=$(cat "$STATE/wallpaper" 2>/dev/null || true)
             [[ -f $f ]] || f=$(default_wall)
             [[ -n $f ]] && set_wall "$f" quiet ;;
    init)    f=${2:-$(cat "$STATE/wallpaper" 2>/dev/null || true)}
             [[ -f $f ]] || f=$(default_wall)
             [[ -n $f ]] || { fallback_colors; exit 0; }
             printf '%s\n' "$(readlink -f "$f")" > "$STATE/wallpaper"
             still "$f" && gen_colors --quiet-terminals ;;
    colors)  gen_colors; reload_all ;;
    *) echo "Nutzung: $0 set <datei> | random | restore | init [datei] | colors" >&2; exit 1 ;;
esac

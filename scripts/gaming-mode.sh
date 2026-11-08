#!/usr/bin/env bash
# Gentoo-rice – Gaming-Modus (Super+Shift+G / Waybar-Icon / Rice-Menü)
#   an:  keine Animationen, kein Blur, keine Schatten, keine Lücken/Transparenz,
#        Video-/Wallpaper-Engine-Hintergrund pausiert
#   aus: alles wie vorher
# Nutzung: gaming-mode.sh [toggle|on|off|status]
set -uo pipefail
FLAG="$HOME/.cache/rice/gaming.lua"
WALL_PROCS=(mpvpaper linux-wallpaperengine)

notify() { if command -v notify-send >/dev/null; then notify-send -a Gentoo-rice "$@" || true; fi; }
waybar_refresh() { pkill -RTMIN+9 -x waybar 2>/dev/null || true; }
is_on() { [[ -f $FLAG ]]; }

on() {
    mkdir -p "$(dirname "$FLAG")"
    printf '%s\n' "-- vom Gaming-Modus angelegt (scripts/gaming-mode.sh off entfernt die Datei)" "return true" > "$FLAG"
    hyprctl reload >/dev/null 2>&1 || true
    for p in "${WALL_PROCS[@]}"; do pkill -STOP -x "$p" 2>/dev/null || true; done
    waybar_refresh
    notify -i input-gaming "Gaming-Modus an" "Keine Effekte, Hintergrund pausiert"
}

off() {
    rm -f "$FLAG"
    hyprctl reload >/dev/null 2>&1 || true
    for p in "${WALL_PROCS[@]}"; do pkill -CONT -x "$p" 2>/dev/null || true; done
    waybar_refresh
    notify -i input-gaming "Gaming-Modus aus" "Effekte wieder an"
}

case ${1:-toggle} in
    toggle) if is_on; then off; else on; fi ;;
    on)     on ;;
    off)    off ;;
    status)
        if is_on; then printf '{"text":"󰊴","class":"on","tooltip":"Gaming-Modus: an (Super+Shift+G)"}\n'
        else printf '{"text":"󰊴","class":"off","tooltip":"Gaming-Modus: aus (Super+Shift+G)"}\n'; fi ;;
    *) echo "Nutzung: $0 [toggle|on|off|status]" >&2; exit 1 ;;
esac

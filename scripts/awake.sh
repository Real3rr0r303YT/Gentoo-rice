#!/usr/bin/env bash
# Gentoo-rice – Wach bleiben / Normal-Modus (Waybar-Icon, Rice-Menü)
#   Wach bleiben: hypridle aus → kein Sperren, kein Bildschirm-Aus (z. B. für lange Builds)
#   Normal:       hypridle läuft wieder (sperrt/abschaltet wie gewohnt)
# Nutzung: awake.sh [toggle|on|off|status]
set -uo pipefail

notify() { if command -v notify-send >/dev/null; then notify-send -a Gentoo-rice "$@" || true; fi; }
waybar_refresh() { pkill -RTMIN+10 -x waybar 2>/dev/null || true; }
is_awake() { ! pgrep -x hypridle >/dev/null; }

on() {
    pkill -x hypridle 2>/dev/null || true
    waybar_refresh
    notify -i caffeine "Wach bleiben an" "Bildschirm sperrt sich nicht und bleibt an"
}

off() {
    if ! pgrep -x hypridle >/dev/null; then (setsid hypridle >/dev/null 2>&1 &); fi
    waybar_refresh
    notify -i caffeine "Normal-Modus" "Sperren und Bildschirm-Aus wieder wie gewohnt"
}

case ${1:-toggle} in
    toggle) if is_awake; then off; else on; fi ;;
    on)     on ;;
    off)    off ;;
    status)
        if is_awake; then printf '{"text":"󰅶","class":"on","tooltip":"Wach bleiben: an – Klick: Normal-Modus"}\n'
        else printf '{"text":"󰛊","class":"off","tooltip":"Normal-Modus – Klick: wach bleiben (kein Sperren)"}\n'; fi ;;
    *) echo "Nutzung: $0 [toggle|on|off|status]" >&2; exit 1 ;;
esac

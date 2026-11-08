#!/usr/bin/env bash
# Gentoo-rice – Handy-Ecosystem: KDE Connect (oder Valent als Flatpak)
#   daemon  Hintergrunddienst starten (mit Hyprland)
#   open    Oberfläche öffnen (koppeln, Dateien senden, Zwischenablage, Benachrichtigungen)
# Copyright (C) 2026 3rr0r303YT – GPL-3.0-or-later
set -uo pipefail

kdeconnectd_bin() {
    local f
    for f in /usr/lib64/libexec/kdeconnectd /usr/libexec/kdeconnectd /usr/lib/libexec/kdeconnectd \
        /usr/lib64/libexec/kf6/kdeconnectd /usr/lib/kdeconnectd; do
        if [[ -x $f ]]; then echo "$f"; return 0; fi
    done
    command -v kdeconnectd
}

case ${1:-open} in
    daemon)
        if d=$(kdeconnectd_bin); then
            pgrep -x kdeconnectd >/dev/null || exec "$d"
        elif flatpak info --user ca.andyholmes.Valent >/dev/null 2>&1; then
            pgrep -f ca.andyholmes.Valent >/dev/null || exec flatpak run ca.andyholmes.Valent --gapplication-service
        fi ;;
    open)
        if command -v kdeconnect-app >/dev/null; then
            if d=$(kdeconnectd_bin); then pgrep -x kdeconnectd >/dev/null || ("$d" >/dev/null 2>&1 &); fi
            exec kdeconnect-app
        elif flatpak info --user ca.andyholmes.Valent >/dev/null 2>&1; then
            exec flatpak run ca.andyholmes.Valent
        else
            notify-send -a Gentoo-rice "KDE Connect fehlt" "Super+D → Apps aktualisieren bzw. ./scripts/apps.sh" 2>/dev/null || true
        fi ;;
    *) echo "Nutzung: $0 [daemon|open]" >&2; exit 1 ;;
esac

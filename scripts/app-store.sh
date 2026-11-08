#!/usr/bin/env bash
# Gentoo-rice – App-Store (Super+Shift+A / Rice-Menü): App-Namen eintippen, auswählen, installieren
#   sucht auf Flathub (Flatpak, ohne sudo) und in Portage (eix, mit sudo)
# Copyright (C) 2026 3rr0r303YT – GPL-3.0-or-later
set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"
THEME="$HOME/.config/rofi/menu.rasi"
STYLE='window { width: 860px; } listview { lines: 14; } inputbar { children: [ "prompt", "entry" ]; }'

pkill -x rofi 2>/dev/null && exit 0
notify() { if command -v notify-send >/dev/null; then notify-send -a App-Store "$@" || true; fi; }

query=$(rofi -dmenu -p "App suchen" -theme "$THEME" -theme-str "$STYLE" -l 0 </dev/null) || exit 0
query=${query//[^[:alnum:] ._+-]/}
[[ -n $query ]] || exit 0

results=$(
    if command -v flatpak >/dev/null; then
        flatpak search --columns=name,application,description "$query" 2>/dev/null |
            awk -F'\t' 'NF >= 2 && $2 != "" { printf "󰏖  %s  ·  %s  ·  Flatpak  ·  %s\n", $1, substr($3, 1, 60), $2 }' | head -n 25
    fi
    if command -v eix >/dev/null; then
        eix --only-names "$query" 2>/dev/null | head -n 25 | sed 's|^|  |; s|$|  ·  Gentoo|'
    fi
)
if [[ -z $results ]]; then
    notify "Nichts gefunden" "Keine App für '$query' (Flathub/Portage)"
    exit 0
fi

choice=$(printf '%s\n' "$results" | rofi -dmenu -i -p "Installieren" -theme "$THEME" -theme-str "$STYLE") || exit 0
[[ -n $choice ]] || exit 0

if [[ $choice == *"·  Flatpak  ·"* ]]; then
    id=${choice##*·  }
    name=$(sed 's/^[^ ]*  //; s/  ·.*//' <<<"$choice")
    # shellcheck disable=SC2016  # $1/$2 werden in der Unter-Shell ausgewertet
    exec kitty --class rice-float --hold sh -c \
        'echo "Installiere $1 ($2) von Flathub …"; flatpak install --user -y flathub "$2" && { echo; echo "Fertig – im Launcher (Super+Leertaste) unter: $1"; notify-send -a App-Store Installiert "$1"; }' \
        sh "$name" "$id"
else
    atom=$(sed 's/^[^ ]*  //; s/  ·  Gentoo$//' <<<"$choice")
    # shellcheck disable=SC2016
    exec kitty --class rice-float --hold sh -c \
        'echo "Installiere $1 (Gentoo, sudo-Passwort nötig) …"; sudo emerge --ask --verbose --getbinpkg --noreplace "$1" && notify-send -a App-Store Installiert "$1"' \
        sh "$atom"
fi

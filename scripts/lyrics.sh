#!/usr/bin/env bash
# Gentoo-rice – Songtext-Overlay (sptlrx) für den aktuellen MPRIS-Player, Super+Y schaltet um
export PATH="$HOME/.local/bin:$PATH"
if pgrep -f 'kitty --class rice-lyrics' >/dev/null; then
    pkill -f 'kitty --class rice-lyrics'; exit 0
fi
if ! command -v sptlrx >/dev/null; then
    notify-send -a Songtext "sptlrx nicht installiert" "./install.sh erneut ausführen" 2>/dev/null; exit 0
fi
exec kitty --class rice-lyrics -o remember_window_size=no -o background_opacity=0.35 \
    -o initial_window_width=80c -o initial_window_height=5c -o font_size=13 \
    sh -c 'sptlrx mpris 2>/dev/null || sptlrx --player mpris'

#!/bin/sh
dir="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Bilder")/Screenshots"
mkdir -p "$dir"
file="$dir/Bildschirmfoto $(date '+%Y-%m-%d um %H.%M.%S').png"
case "$1" in
    area) geo=$(slurp -d -b '#1C1C1E66' -c '#0A84FF' -w 1) || exit 0
          grim -g "$geo" "$file" ;;
    *)    grim "$file" ;;
esac
wl-copy < "$file"
notify-send -a Bildschirmfoto -i "$file" "Bildschirmfoto gesichert" "In Zwischenablage kopiert"

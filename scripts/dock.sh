#!/bin/sh
# Dock unten mittig, auto-hide
pkill -x nwg-dock-hyprla 2>/dev/null
exec nwg-dock-hyprland -d -hd 300 -i 42 -mb 8 -p bottom -a center -nolauncher -s style.css

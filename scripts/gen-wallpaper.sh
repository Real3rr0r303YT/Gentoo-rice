#!/bin/sh
# Erzeugt einen weichen, dunklen Verlauf (ImageMagick 7).
# Nutzung: gen-wallpaper.sh [BREITExHÖHE] [Ausgabe]
set -e
mkdir -p "$HOME/Pictures/wallpapers"
size=${1:-2880x1800}
out=${2:-"$HOME/Pictures/wallpapers/gradient-$(date +%s).png"}
w=${size%x*}; h=${size#*x}
magick -size "$size" xc:'#141416' \
  \( -size "$((w*3/2))x$((h*3/2))" radial-gradient:'#1b2b48'-'#141416' -geometry -"$((w/2))"-"$((h/2))" \) -compose lighten -composite \
  \( -size "$((w*3/2))x$((h*3/2))" radial-gradient:'#2a1f3d'-'#141416' -geometry +"$((w/3))"+"$((h/3))" \) -compose lighten -composite \
  \( -size "$size" radial-gradient:'#00000000'-'#0000008c' \) -compose over -composite \
  -attenuate 0.4 +noise Uniform -depth 8 "$out"
echo "Wallpaper: $out"

#!/usr/bin/env bash
# Gentoo-rice – Login-Screen (SDDM) und hyprlock mit dem aktuellen Rice abgleichen
#   - unscharfes Wallpaper, Farbpalette, runder Avatar
#   - läuft als normaler Benutzer (kein sudo), wird von wallpaper.sh/theme.sh aufgerufen
# Ziel: /var/lib/gentoo-rice/sddm (vom Benutzer beschreibbar, für SDDM lesbar)
set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"

STATE="$HOME/.cache/rice"
WAL="$HOME/.cache/wal"
DEST="${GENTOO_RICE_SDDM_DIR:-/var/lib/gentoo-rice/sddm}"
mkdir -p "$STATE"
command -v magick >/dev/null || { echo "ImageMagick (magick) fehlt" >&2; exit 1; }

# ── Avatar (rund, 256 px) → ~/.cache/rice/avatar.png (auch für hyprlock) ──
accent="#7aa2f7"; accent2="#bb9af7"
if [[ -f $WAL/sddm-colors.conf ]]; then
    accent=$(sed -n 's/^accent=//p' "$WAL/sddm-colors.conf"); accent=${accent:-#7aa2f7}
    accent2=$(sed -n 's/^accent2=//p' "$WAL/sddm-colors.conf"); accent2=${accent2:-#bb9af7}
fi
src=""
for f in "$HOME/.face" "$HOME/.face.icon"; do [[ -s $f ]] && { src=$f; break; }; done
tmp=$(mktemp --suffix=.png)
if [[ -n $src ]] && magick "${src}[0]" -resize 256x256^ -gravity center -extent 256x256 "$tmp" 2>/dev/null; then
    :
else
    # Platzhalter: blauer Verlauf + Initiale
    accent="#3b82f6"; accent2="#22d3ee"
    initial=$(id -un | cut -c1 | tr '[:lower:]' '[:upper:]')
    magick -size 256x256 gradient:"$accent"-"$accent2" -gravity center \
        -fill white -pointsize 128 -annotate +0+6 "$initial" "$tmp"
fi
magick "$tmp" \( +clone -alpha extract -fill black -colorize 100 -fill white -draw "circle 128,128 128,1" \) \
    -alpha off -compose CopyOpacity -composite "$STATE/avatar.png"
rm -f "$tmp"

# ── Ab hier nur, wenn der Login-Screen eingerichtet ist ───────
[[ -d $DEST && -w $DEST ]] || exit 0

# Unscharfes Wallpaper (verkleinern → weichzeichnen → hochskalieren geht schnell)
if [[ -f $STATE/current.png ]]; then
    magick "$STATE/current.png" -resize 1920x1080^ -gravity center -extent 1920x1080 \
        -resize 25% -blur 0x6 -resize 400% -modulate 90 -quality 88 "$DEST/background.jpg.new" &&
        mv "$DEST/background.jpg.new" "$DEST/background.jpg"
fi
install -m 0644 "$STATE/avatar.png" "$DEST/avatar.png"

# Farben + Pfade für das SDDM-Theme
{
    if [[ -f $WAL/sddm-colors.conf ]]; then cat "$WAL/sddm-colors.conf"; else echo "[General]"; fi
    echo "background=$DEST/background.jpg"
    echo "avatar=$DEST/avatar.png"
} > "$DEST/theme.conf.user.new" && mv "$DEST/theme.conf.user.new" "$DEST/theme.conf.user"
chmod 0644 "$DEST"/* 2>/dev/null || true
echo "Login-Screen aktualisiert ($DEST)"

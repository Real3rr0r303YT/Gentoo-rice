#!/usr/bin/env bash
# Gentoo-rice – Theme-Wechsler
# Nutzung: theme.sh list | current | set <name>
#   Ein Theme setzt Farben (Hyprland, Waybar, kitty, rofi, mako, cava, btop, hyprlock, GTK),
#   Optik (Gaps, Rundung, Transparenz, Blur), Hell/Dunkel und optional ein Verlaufs-Wallpaper.
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"

REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
THEMES="$REPO/themes"
STATE="$HOME/.cache/rice"
mkdir -p "$STATE/themes"

notify() { if command -v notify-send >/dev/null; then notify-send -a Theme "$@" || true; fi; }

load_theme() { # load_theme <name> → setzt die Variablen aus theme.conf
    local file="$THEMES/$1/theme.conf"
    [[ -f $file ]] || { echo "Theme nicht gefunden: $1 (verfügbar: $(list_names | tr '\n' ' '))" >&2; exit 1; }
    # shellcheck disable=SC2034  # FG/NAME kommen aus theme.conf und sind dort dokumentiert
    MODE=dynamic SCHEME=dark BG="" FG="" PALETTE="" WALLPAPER=keep NAME=$1 DESC=""
    GAPS_IN=5 GAPS_OUT=10 ROUNDING=10 BORDER=2 ACTIVE_OPACITY=0.85 INACTIVE_OPACITY=0.75 BLUR_SIZE=12 BLUR_PASSES=4
    CURSOR=Bibata-Modern-Ice CURSOR_SIZE=24
    # shellcheck source=/dev/null
    source "$file"
}

list_names() { find "$THEMES" -mindepth 2 -maxdepth 2 -name theme.conf -printf '%h\n' | xargs -rn1 basename | sort; }

# Verlaufs-Wallpaper aus den Theme-Farben (ImageMagick)
gradient() { # gradient <ausgabe>
    local out=$1 w=2880 h=1800 a1 a2 mode=lighten
    read -ra P <<<"$PALETTE"
    a1=${P[4]}; a2=${P[5]}
    [[ $SCHEME == light ]] && mode=darken
    # Glows deutlich größer als das Bild, damit keine Kanten entstehen
    local gw=$((w * 12 / 5)) gh=$((h * 12 / 5))
    magick -size "${w}x${h}" xc:"$BG" \
        \( -size "${gw}x${gh}" radial-gradient:"$a1"-"$BG" -fill "$BG" -colorize 62% \) \
            -geometry "-$((w * 100 / 100))-$((h * 105 / 100))" -compose "$mode" -composite \
        \( -size "${gw}x${gh}" radial-gradient:"$a2"-"$BG" -fill "$BG" -colorize 68% \) \
            -geometry "-$((w * 40 / 100))-$((h * 35 / 100))" -compose "$mode" -composite \
        -attenuate 0.3 +noise Uniform -depth 8 "$out"
}

set_theme() {
    local name=$1 wp last
    load_theme "$name"
    printf '%s\n' "$name" > "$STATE/theme"

    # Optik für hypr/hyprland.lua
    cat > "$STATE/theme-hypr.lua" <<LUA
-- von scripts/theme.sh erzeugt (Theme: $name)
return {
    gaps_in          = $GAPS_IN,
    gaps_out         = $GAPS_OUT,
    rounding         = $ROUNDING,
    border_size      = $BORDER,
    active_opacity   = $ACTIVE_OPACITY,
    inactive_opacity = $INACTIVE_OPACITY,
    blur_size        = $BLUR_SIZE,
    blur_passes      = $BLUR_PASSES,
    cursor           = "$CURSOR",
    cursor_size      = $CURSOR_SIZE,
}
LUA

    # Hell/Dunkel für GTK/libadwaita
    if command -v gsettings >/dev/null; then
        if [[ $SCHEME == light ]]; then
            gsettings set org.gnome.desktop.interface color-scheme prefer-light 2>/dev/null || true
            gsettings set org.gnome.desktop.interface gtk-theme Adwaita 2>/dev/null || true
        else
            gsettings set org.gnome.desktop.interface color-scheme prefer-dark 2>/dev/null || true
            gsettings set org.gnome.desktop.interface gtk-theme Adwaita-dark 2>/dev/null || true
        fi
    fi

    # Mauszeiger
    "$REPO/scripts/cursor.sh" "$CURSOR" "$CURSOR_SIZE" >/dev/null || true

    # Wallpaper + Farben (wallpaper.sh rendert die Theme-Palette bzw. pywal)
    if [[ $MODE == static && $WALLPAPER == gradient ]]; then
        wp="$STATE/themes/$name.png"
        if [[ ! -s $wp || $THEMES/$name/theme.conf -nt $wp ]]; then gradient "$wp"; fi
        "$REPO/scripts/wallpaper.sh" set "$wp" quiet
    else
        last=$(cat "$STATE/wallpaper" 2>/dev/null || true)
        if [[ $last == "$STATE/themes/"* ]]; then
            # vom Verlauf eines festen Themes zurück zu einem echten Wallpaper
            "$REPO/scripts/wallpaper.sh" restore-default
        else
            "$REPO/scripts/wallpaper.sh" colors
        fi
    fi
    notify -i "$STATE/current.png" "Theme: $name" "$DESC"
}

case "${1:-}" in
    list)    for n in $(list_names); do (load_theme "$n"; printf '%s\t%s\t%s\n' "$n" "$MODE" "$DESC"); done ;;
    current) cat "$STATE/theme" 2>/dev/null || echo lofi ;;
    set)     [[ -n ${2:-} ]] || { echo "Nutzung: $0 set <name>" >&2; exit 1; }; set_theme "$2" ;;
    *)       echo "Nutzung: $0 list | current | set <name>" >&2; exit 1 ;;
esac

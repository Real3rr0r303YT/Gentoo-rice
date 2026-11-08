#!/usr/bin/env bash
# Gentoo-rice – Rice-Menü (Super+D / Paletten-Icon in der Waybar):
# Apps, Spotify, Minecraft, Roblox (Sober), OBS, Theme, Wallpaper, Login-Screen, Update, Tastenkürzel, Power
set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"
DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
THEME="$HOME/.config/rofi/menu.rasi"

pkill -x rofi 2>/dev/null && exit 0

notify() { command -v notify-send >/dev/null && notify-send -a Gentoo-rice "$@"; return 0; }

keys() {
    printf '%s\n' \
        "Super + D              Rice-Menü" \
        "Super + Shift + T      Theme ändern" \
        "Super + W              Wallpaper wählen" \
        "Super + Shift + W      Zufalls-Wallpaper" \
        "Super + F              Firefox" \
        "Super + Shift + F      Vollbild" \
        "Super + Enter          Terminal" \
        "Super + Leertaste      Apps (rofi)" \
        "Super + E              Dateien" \
        "Super + G              Steam" \
        "Super + S              Spotify" \
        "Super + K              Claude Code" \
        "Super + Q              Fenster schließen" \
        "Super + V              Schwebend an/aus" \
        "Super + L              Sperren" \
        "Super + Shift + E      Power-Menü" \
        "Super + 1–6            Arbeitsfläche" \
        "Super + A / T / M / C / I   cava / btop / cmatrix / Uhr / fastfetch" \
        "Druck / Shift + Druck  Screenshot Bereich / ganz" |
        rofi -dmenu -i -p "Tasten" -theme "$THEME" -theme-str 'window { width: 620px; } listview { lines: 12; } inputbar { children: [ "prompt", "entry" ]; }' >/dev/null
}

choice=$(printf '%s\n' \
    "󰀻  Apps" \
    "󰓇  Spotify" \
    "󰍳  Minecraft" \
    "󰺵  Roblox (Sober)" \
    "󰕧  OBS Studio" \
    "󰏘  Theme ändern" \
    "󰋩  Wallpaper wählen" \
    "󰒝  Zufalls-Wallpaper" \
    "󰍂  Login-Screen angleichen" \
    "󰚰  Rice aktualisieren" \
    "󰌌  Tastenkürzel" \
    "󰐥  Power-Menü" |
    rofi -dmenu -i -p "Rice" -theme "$THEME" -theme-str 'window { width: 320px; } listview { lines: 12; }')

case "$choice" in
    *"  Apps")            exec rofi -show drun ;;
    *"  Spotify")         exec flatpak run com.spotify.Client ;;
    *"  Minecraft")       exec flatpak run com.mojang.Minecraft ;;
    *"Roblox (Sober)")    exec flatpak run org.vinegarhq.Sober ;;
    *"  OBS Studio")      exec flatpak run com.obsproject.Studio ;;
    *"Theme ändern")      exec "$DIR/theme-picker.sh" ;;
    *"Wallpaper wählen")  exec "$DIR/wallpaper-picker.sh" ;;
    *"Zufalls-Wallpaper") exec "$DIR/wallpaper.sh" random ;;
    *"Login-Screen angleichen")
        if "$DIR/sddm-sync.sh" >/dev/null 2>&1; then notify "Login-Screen" "an Wallpaper und Avatar angeglichen"
        else notify "Login-Screen" "nicht eingerichtet – ./install.sh --login"; fi ;;
    *"Rice aktualisieren") exec kitty --class rice-float --hold "$DIR/update.sh" ;;
    *"Tastenkürzel")      keys ;;
    *"Power-Menü")        exec "$DIR/powermenu.sh" ;;
esac
exit 0

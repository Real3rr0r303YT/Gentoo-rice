#!/usr/bin/env bash
# Gentoo-rice – Rice-Menü (Super+D / Paletten-Icon in der Waybar):
# Gaming-Modus, Apps, Spotify, Minecraft, Roblox, CurseForge, Mullvad VPN, Tor, OBS, Theme, Wallpaper, Login-Screen, Update, Tastenkürzel, Power
set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"
DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
THEME="$HOME/.config/rofi/menu.rasi"

pkill -x rofi 2>/dev/null && exit 0

notify() { command -v notify-send >/dev/null && notify-send -a Gentoo-rice "$@"; return 0; }

keys() {
    printf '%s\n' \
        "Super + D              Rice-Menü" \
        "Super + Shift + A      App-Store" \
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
        "Super + Shift + G      Gaming-Modus an/aus" \
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
    "󰊗  Gaming-Modus an/aus" \
    "󰀻  Apps" \
    "󰏖  App-Store (Apps suchen + installieren)" \
    "󰓇  Spotify" \
    "󰍳  Minecraft" \
    "󰺵  Roblox (Sober)" \
    "󰺵  Roblox Studio (Vinegar)" \
    "󰄜  Handy verbinden (KDE Connect)" \
    "󰪺  CurseForge" \
    "󰖂  Mullvad VPN" \
    "󰇮  Proton Mail" \
    "󰃭  Proton Calendar" \
    "󰒃  Tor Browser" \
    "󰕥  Virenschutz installieren/aktualisieren" \
    "󰕥  Virenscan (Home)" \
    "󰨟  Quarantäne öffnen" \
    "󰍹  Virtuelle Maschinen (Windows/Linux testen)" \
    "󰕧  OBS Studio" \
    "󰏘  Theme ändern" \
    "󰋩  Wallpaper wählen" \
    "󰒝  Zufalls-Wallpaper" \
    "󰍂  Login-Screen angleichen" \
    "󰚰  Apps aktualisieren" \
    "󰚰  Rice aktualisieren" \
    "󰣧  Gentoo aktualisieren (emerge @world)" \
    "󰌌  Tastenkürzel" \
    "󰐥  Power-Menü" |
    rofi -dmenu -i -p "Rice" -theme "$THEME" -theme-str 'window { width: 420px; } listview { lines: 20; }')

case "$choice" in
    *"  Apps")            exec rofi -show drun ;;
    *"App-Store"*)        exec "$DIR/app-store.sh" ;;
    *"  Spotify")         exec flatpak run com.spotify.Client ;;
    *"  Minecraft")       exec flatpak run com.mojang.Minecraft ;;
    *"Roblox (Sober)")    exec flatpak run org.vinegarhq.Sober ;;
    *"Roblox Studio (Vinegar)") exec flatpak run org.vinegarhq.Vinegar ;;
    *"Handy verbinden"*)  exec "$DIR/phone.sh" open ;;
    *"Virtuelle Maschinen"*) exec "$DIR/vm.sh" open ;;
    *"  OBS Studio")      exec flatpak run com.obsproject.Studio ;;
    *"Gaming-Modus an/aus") exec "$DIR/gaming-mode.sh" toggle ;;
    *"Virenschutz installieren/aktualisieren") exec kitty --class rice-float --hold "$DIR/antivirus.sh" update ;;
    *"Virenscan (Home)")  exec kitty --class rice-float --hold "$DIR/antivirus.sh" scan "$HOME" ;;
    *"Quarantäne öffnen") mkdir -p "$HOME/.local/share/gentoo-rice/quarantine"; exec thunar "$HOME/.local/share/gentoo-rice/quarantine" ;;
    *"  CurseForge")      exec flatpak run com.overwolf.curseforge ;;
    *"  Mullvad VPN")     exec "$DIR/mullvad.sh" open ;;
    *"  Proton Mail")     exec "$DIR/webapp.sh" https://mail.proton.me ;;
    *"  Proton Calendar") exec "$DIR/webapp.sh" https://calendar.proton.me ;;
    *"  Tor Browser")
        if flatpak info --user org.torproject.torbrowser-launcher >/dev/null 2>&1; then exec flatpak run org.torproject.torbrowser-launcher
        else exec flatpak run com.github.micahflee.torbrowser-launcher; fi ;;
    *"Theme ändern")      exec "$DIR/theme-picker.sh" ;;
    *"Wallpaper wählen")  exec "$DIR/wallpaper-picker.sh" ;;
    *"Zufalls-Wallpaper") exec "$DIR/wallpaper.sh" random ;;
    *"Login-Screen angleichen")
        if "$DIR/sddm-sync.sh" >/dev/null 2>&1; then notify "Login-Screen" "an Wallpaper und Avatar angeglichen"
        else notify "Login-Screen" "nicht eingerichtet – ./install.sh --login"; fi ;;
    *"Apps aktualisieren") exec kitty --class rice-float --hold "$DIR/apps.sh" update ;;
    *"Rice aktualisieren") exec kitty --class rice-float --hold "$DIR/update.sh" ;;
    *"Gentoo aktualisieren"*)
        # shellcheck disable=SC2016  # $1 wird in der Unter-Shell ausgewertet
        exec kitty --hold sh -c 'echo "Gentoo komplett aktualisieren: Portage-Sync, Hyprland, emerge @world, Flatpaks (sudo-Passwort nötig)"; echo; "$1/update.sh" --system; echo; echo "Fertig – nach Kernel-/Hyprland-Updates neu starten: loginctl reboot"' sh "$DIR" ;;
    *"Tastenkürzel")      keys ;;
    *"Power-Menü")        exec "$DIR/powermenu.sh" ;;
esac
exit 0

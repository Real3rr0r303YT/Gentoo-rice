#!/usr/bin/env bash
# Gentoo-rice – zusätzliche Einträge für den App-Launcher (Super+Leertaste)
#   Proton Mail/Calendar/Pass (Web), Virtuelle Maschinen, App-Store, Rice-Menü, Virenscan
# Wird von update.sh/apps.sh aufgerufen; ohne sudo.
set -uo pipefail
APPDIR="$HOME/.local/share/applications"
S="$HOME/.local/share/gentoo-rice/scripts"
mkdir -p "$APPDIR"

entry() { # entry <id> <Name> <Exec> <Icon> <Kategorien> [Kommentar]
    cat > "$APPDIR/gentoo-rice-$1.desktop" <<DESK
[Desktop Entry]
Type=Application
Name=$2
Comment=${6:-$2}
Exec=$3
Icon=$4
Categories=$5
Terminal=false
DESK
}

entry proton-mail     "Proton Mail"      "$S/webapp.sh https://mail.proton.me"     mail-client             "Office;Email;"   "Proton Mail (Web-App, kostenlos)"
entry proton-calendar "Proton Calendar"  "$S/webapp.sh https://calendar.proton.me" x-office-calendar       "Office;Calendar;" "Proton Calendar (Web-App)"
entry proton-pass-web "Proton Pass (Web)" "$S/webapp.sh https://pass.proton.me"    dialog-password         "Utility;Security;" "Proton Pass im Browser"
entry vm              "Virtuelle Maschinen" "$S/vm.sh open"                         computer                "System;Emulator;" "Windows/Linux testen (GNOME Boxes)"
entry app-store       "App-Store"        "$S/app-store.sh"                          system-software-install "System;PackageManager;" "Apps suchen und installieren"
entry rice-menu       "Rice-Menü"        "$S/rice-menu.sh"                          preferences-desktop     "Settings;"       "Theme, Wallpaper, Updates … (Super+D)"
entry virenscan       "Virenscan"        "kitty --class rice-float --hold $S/antivirus.sh scan"     security-high "System;Security;" "Home-Ordner mit ClamAV prüfen"
entry gentoo-update   "Gentoo aktualisieren" "kitty --hold $S/update.sh --system"   system-software-update  "System;"         "Sync, Hyprland, emerge @world, Flatpaks"

# alte Einträge aus apps.sh (vor diesem Skript) entfernen
rm -f "$APPDIR/proton-mail.desktop" "$APPDIR/proton-calendar.desktop"
command -v update-desktop-database >/dev/null && update-desktop-database -q "$APPDIR" 2>/dev/null
exit 0

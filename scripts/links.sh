# shellcheck shell=bash disable=SC2034  # Variablen werden von install.sh/uninstall.sh genutzt
# Gemeinsame Definitionen für install.sh / uninstall.sh
# Format: "Quelle im Repo|Ziel relativ zu \$HOME"
LINKS=(
    "hypr|.config/hypr"
    "waybar|.config/waybar"
    "kitty|.config/kitty"
    "rofi|.config/rofi"
    "wal/templates|.config/wal/templates"
    "fastfetch|.config/fastfetch"
    "gtk/gtk-3.0/settings.ini|.config/gtk-3.0/settings.ini"
    "gtk/gtk-4.0/settings.ini|.config/gtk-4.0/settings.ini"
    ".|.local/share/gentoo-rice"
)
# Frühere Versionen des Rice (werden bei install/uninstall aufgeräumt)
LEGACY_LINKS=( ".config/wofi" ".config/mako" ".config/nwg-dock-hyprland" )
# Im Repo angelegte Links auf generierte Farben (gitignored)
GENERATED_LINKS=(
    "waybar/colors.css|.cache/wal/colors-waybar.css"
    "kitty/colors-wal.conf|.cache/wal/colors-kitty.conf"
)
# Links auf generierte Dateien im Cache: "Ziel unter \$HOME|Link relativ zu \$HOME"
CACHE_LINKS=(
    ".cache/wal/gtk-colors.css|.config/gtk-3.0/gtk.css"
    ".cache/wal/gtk-colors.css|.config/gtk-4.0/gtk.css"
)
# Flatpaks für .exe-Spiele / Proton
PROTON_FLATPAKS=(
    com.valvesoftware.Steam.CompatibilityTool.Proton-GE
    net.davidotek.pupgui2
    com.usebottles.bottles
)
WALLPAPER_DIR="$HOME/Pictures/wallpapers"
BACKUP_ROOT="$HOME/.config-backup/gentoo-rice"
PROFILE_BEGIN="# >>> gentoo-rice >>>"
PROFILE_END="# <<< gentoo-rice <<<"
# Zusätzliche (dynamische) Links, z. B. Firefox-Profil – relativ zu $HOME
EXTRA_LINKS_FILE="$HOME/.local/state/gentoo-rice/extra-links"
FASTFETCH_BEGIN="# >>> gentoo-rice fastfetch >>>"
FASTFETCH_END="# <<< gentoo-rice fastfetch <<<"

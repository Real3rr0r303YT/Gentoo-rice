# shellcheck shell=bash
# Gemeinsame Definitionen für install.sh / uninstall.sh
# Format: "Quelle im Repo|Ziel relativ zu \$HOME"
LINKS=(
    "hypr|.config/hypr"
    "waybar|.config/waybar"
    "kitty|.config/kitty"
    "wofi|.config/wofi"
    "mako|.config/mako"
    "nwg-dock-hyprland|.config/nwg-dock-hyprland"
    "fastfetch|.config/fastfetch"
    "gtk/gtk-3.0/settings.ini|.config/gtk-3.0/settings.ini"
    "gtk/gtk-4.0/settings.ini|.config/gtk-4.0/settings.ini"
    ".|.local/share/gentoo-rice"
)
BACKUP_ROOT="$HOME/.config-backup/gentoo-rice"
PROFILE_BEGIN="# >>> gentoo-rice >>>"
PROFILE_END="# <<< gentoo-rice <<<"
# Zusätzliche (dynamische) Links, z. B. Firefox-Profil – relativ zu $HOME
EXTRA_LINKS_FILE="$HOME/.local/state/gentoo-rice/extra-links"
FASTFETCH_BEGIN="# >>> gentoo-rice fastfetch >>>"
FASTFETCH_END="# <<< gentoo-rice fastfetch <<<"

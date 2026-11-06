#!/usr/bin/env bash
# Gentoo-rice – Mauszeiger überall setzen (Hyprland, GTK/gsettings, XWayland-Apps)
# Nutzung: cursor.sh <theme> [größe]     z. B. cursor.sh Bibata-Modern-Ice 24
set -uo pipefail
theme=${1:-Bibata-Modern-Ice}
size=${2:-24}

found=""
for d in "$HOME/.local/share/icons" "$HOME/.icons" /usr/share/icons; do
    [[ -d $d/$theme/cursors ]] && { found=$d/$theme; break; }
done
if [[ -z $found ]]; then
    echo "Zeiger-Theme $theme nicht installiert (./install.sh lädt Bibata)" >&2
    exit 1
fi

# XWayland-/Fallback-Zeiger
mkdir -p "$HOME/.icons/default"
printf '[Icon Theme]\nInherits=%s\n' "$theme" > "$HOME/.icons/default/index.theme"

# GTK / libadwaita
if command -v gsettings >/dev/null; then
    gsettings set org.gnome.desktop.interface cursor-theme "$theme" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface cursor-size "$size" 2>/dev/null || true
fi

# Laufendes Hyprland sofort umstellen
if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && command -v hyprctl >/dev/null; then
    hyprctl setcursor "$theme" "$size" >/dev/null 2>&1 || true
fi
echo "Zeiger: $theme ($size px)"

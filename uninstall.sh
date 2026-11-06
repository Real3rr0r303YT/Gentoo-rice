#!/usr/bin/env bash
# Gentoo-rice – Deinstallation (Symlinks entfernen, Backup zurückspielen)
# Copyright (C) 2026 3rr0r303YT – GPL-3.0-or-later
set -Eeuo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/links.sh
source "$REPO/scripts/links.sh"

if [[ -t 1 ]]; then B=$'\e[1m'; R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'; else B=; R=; G=; Y=; N=; fi
ok()   { printf '  %s✔%s %s\n' "$G" "$N" "$*"; }
warn() { printf '  %s!%s %s\n' "$Y" "$N" "$*"; }
trap 'printf "%s✘ Fehler bei: %s%s\n" "$R$B" "$BASH_COMMAND" "$N" >&2' ERR
[[ $EUID -ne 0 ]] || { echo "Bitte als normaler Benutzer starten."; exit 1; }

# Alle verwalteten Pfade (relativ zu $HOME): feste Links + dynamische (Firefox-Profil)
RELS=()
for entry in "${LINKS[@]}"; do RELS+=("${entry#*|}"); done
RELS+=("${LEGACY_LINKS[@]}")
if [[ -f $EXTRA_LINKS_FILE ]]; then
    while IFS= read -r rel; do [[ -n $rel ]] && RELS+=("$rel"); done < "$EXTRA_LINKS_FILE"
fi

printf '%sSymlinks entfernen%s\n' "$B" "$N"
for rel in "${RELS[@]}"; do
    dst="$HOME/$rel"
    if [[ -L $dst && "$(readlink -f "$dst")" == "$REPO"/* || -L $dst && "$(readlink -f "$dst")" == "$REPO" ]]; then
        rm "$dst"; ok "entfernt: ~/$rel"
    fi
done
rm -f "$REPO/hypr/version.conf" 2>/dev/null || true
for entry in "${GENERATED_LINKS[@]}"; do rm -f "$REPO/${entry%%|*}"; done
# GTK-Farben-Links (zeigen in den Cache) entfernen; Backups folgen unten
for entry in "${CACHE_LINKS[@]}"; do
    dst="$HOME/${entry#*|}"
    if [[ -L $dst && "$(readlink "$dst")" == "$HOME/${entry%%|*}" ]]; then rm "$dst"; ok "entfernt: ~/${entry#*|}"; fi
    RELS+=("${entry#*|}")
done

printf '%sBackup zurückspielen%s\n' "$B" "$N"
if [[ -d $BACKUP_ROOT ]]; then
    # ältestes Backup zuerst = Originalzustand vor der ersten Installation
    while IFS= read -r dir; do
        for rel in "${RELS[@]}"; do
            if [[ -e $dir/$rel || -L $dir/$rel ]]; then
                if [[ -e $HOME/$rel || -L $HOME/$rel ]]; then
                    warn "existiert bereits, übersprungen: ~/$rel (Backup bleibt in $dir)"
                else
                    mkdir -p "$(dirname "$HOME/$rel")"
                    mv "$dir/$rel" "$HOME/$rel"; ok "wiederhergestellt: ~/$rel"
                fi
            fi
        done
        find "$dir" -depth -type d -empty -delete 2>/dev/null || true
    done < <(find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d | sort)
    rmdir "$BACKUP_ROOT" 2>/dev/null || true
else
    warn "kein Backup gefunden"
fi

printf '%sAutostart entfernen%s\n' "$B" "$N"
for prof in "$HOME/.bash_profile" "$HOME/.zprofile"; do
    if [[ -f $prof ]] && grep -qF "$PROFILE_BEGIN" "$prof"; then
        sed -i "/$PROFILE_BEGIN/,/$PROFILE_END/d" "$prof"; ok "${prof/#$HOME/\~}"
    fi
done
if [[ -f $HOME/.bashrc ]] && grep -qF "$FASTFETCH_BEGIN" "$HOME/.bashrc"; then
    sed -i "/$FASTFETCH_BEGIN/,/$FASTFETCH_END/d" "$HOME/.bashrc"; ok "fastfetch-Autostart aus ~/.bashrc"
fi
rm -f "$EXTRA_LINKS_FILE"
PINNED="$HOME/.cache/nwg-dock-pinned"
[[ -f $PINNED ]] && sed -i '/^firefox-bin$/d' "$PINNED" && ok "Firefox aus Dock entfernt"

printf '%sFirefox-Policies entfernen%s\n' "$B" "$N"
SUDO=
if command -v sudo >/dev/null; then SUDO=sudo; elif command -v doas >/dev/null; then SUDO=doas; fi
for f in /etc/firefox/policies/policies.json /opt/firefox/distribution/policies.json; do
    { [[ -f $f ]] && cmp -s "$f" "$REPO/firefox/policies.json"; } || continue
    if [[ $f == /opt/* ]]; then
        if printf '{\n    "policies": {\n        "DisableAppUpdate": true\n    }\n}\n' | $SUDO tee "$f" >/dev/null; then
            ok "zurückgesetzt: $f"
        else
            warn "nicht änderbar: $f"
        fi
    else
        if $SUDO rm -f "$f"; then ok "entfernt: $f"; else warn "nicht entfernbar: $f"; fi
    fi
done

printf '%sWallpaper & Cache%s\n' "$B" "$N"
pkill -x mpvpaper 2>/dev/null || true
"$REPO/scripts/we-set.sh" stop 2>/dev/null || true
if [[ -d $HOME/.local/opt/linux-wallpaperengine || -d $HOME/.local/src/linux-wallpaperengine ]]; then
    rm -rf "$HOME/.local/opt/linux-wallpaperengine" "$HOME/.local/src/linux-wallpaperengine"
    ok "linux-wallpaperengine (Build + Quellcode) entfernt"
fi
if [[ -f $HOME/.local/bin/linux-wallpaperengine ]] && grep -q 'Gentoo-rice' "$HOME/.local/bin/linux-wallpaperengine"; then
    rm "$HOME/.local/bin/linux-wallpaperengine"
fi
WE_CONF_FILE="$HOME/.config/gentoo-rice/wallpaperengine.conf"
if [[ -f $WE_CONF_FILE ]] && cmp -s "$WE_CONF_FILE" "$REPO/config/wallpaperengine.conf"; then
    rm "$WE_CONF_FILE"; rmdir "$HOME/.config/gentoo-rice" 2>/dev/null || true
    ok "Wallpaper-Engine-Config entfernt"
elif [[ -f $WE_CONF_FILE ]]; then
    warn "geänderte Config bleibt erhalten: ~/.config/gentoo-rice/wallpaperengine.conf"
fi
for f in "$REPO"/wallpapers/*.jpg; do
    w="$WALLPAPER_DIR/$(basename "$f")"
    if [[ -f $w ]] && cmp -s "$f" "$w"; then rm "$w"; ok "Platzhalter entfernt: ${w/#$HOME/\~}"; fi
done
rmdir "$WALLPAPER_DIR" 2>/dev/null || true
rm -rf "$HOME/.cache/rice" && ok "$HOME/.cache/rice (Thumbnails) entfernt"
[[ -f $HOME/.config/btop/btop.conf ]] && sed -i 's/^color_theme *=.*/color_theme = "Default"/' "$HOME/.config/btop/btop.conf" || true

if [[ -f $HOME/.icons/default/index.theme ]] && grep -qE 'WhiteSur-cursors|Bibata-Modern' "$HOME/.icons/default/index.theme"; then
    rm "$HOME/.icons/default/index.theme"; ok "Cursor-Default entfernt"
fi

printf '\n%sFertig.%s Pakete, Steam, Proton/Bottles, Workshop-Wallpaper, pywal16 (~/.cache/wal), Themes, eigene Wallpaper, Standardbrowser und /etc/portage/*/gentoo-rice bleiben erhalten.\n' "$G$B" "$N"

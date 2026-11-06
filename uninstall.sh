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
SUDO=; command -v sudo >/dev/null && SUDO=sudo || { command -v doas >/dev/null && SUDO=doas; }
for f in /etc/firefox/policies/policies.json /opt/firefox/distribution/policies.json; do
    [[ -f $f ]] && cmp -s "$f" "$REPO/firefox/policies.json" || continue
    if [[ $f == /opt/* ]]; then
        printf '{\n    "policies": {\n        "DisableAppUpdate": true\n    }\n}\n' | $SUDO tee "$f" >/dev/null \
            && ok "zurückgesetzt: $f" || warn "nicht änderbar: $f"
    else
        $SUDO rm -f "$f" && ok "entfernt: $f" || warn "nicht entfernbar: $f"
    fi
done

printf '%sWallpaper & Cache%s\n' "$B" "$N"
pkill -x mpvpaper 2>/dev/null || true
for f in "$REPO"/wallpapers/*.jpg; do
    w="$WALLPAPER_DIR/$(basename "$f")"
    if [[ -f $w ]] && cmp -s "$f" "$w"; then rm "$w"; ok "Platzhalter entfernt: ${w/#$HOME/\~}"; fi
done
rmdir "$WALLPAPER_DIR" 2>/dev/null || true
rm -rf "$HOME/.cache/rice" && ok "~/.cache/rice (Thumbnails) entfernt"
[[ -f $HOME/.config/btop/btop.conf ]] && sed -i 's/^color_theme *=.*/color_theme = "Default"/' "$HOME/.config/btop/btop.conf" || true

if [[ -f $HOME/.icons/default/index.theme ]] && grep -qE 'WhiteSur-cursors|Bibata-Modern-Classic' "$HOME/.icons/default/index.theme"; then
    rm "$HOME/.icons/default/index.theme"; ok "Cursor-Default entfernt"
fi

printf '\n%sFertig.%s Pakete, Steam, pywal16 (~/.cache/wal), Themes, eigene Wallpaper, Standardbrowser und /etc/portage/*/gentoo-rice bleiben erhalten.\n' "$G$B" "$N"

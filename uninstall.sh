#!/usr/bin/env bash
# Gentoo-rice – Deinstallation (Symlinks entfernen, Backup zurückspielen)
# Copyright (C) 2026 3rr0r303YT – GPL-3.0-or-later
set -Eeuo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/links.sh
source "$REPO/scripts/links.sh"

if [[ -t 1 ]]; then B=$'\e[1m'; R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'; else B=; R=; G=; Y=; N=; fi
ok()   { printf '  %s✔%s %s\n' "$G" "$N" "$*"; }
warn() { printf '  %s!%s %s\n' "$Y" "$N" "$*"; }
trap 'printf "%s✘ Fehler bei: %s%s\n" "$R$B" "$BASH_COMMAND" "$N" >&2' ERR
[[ $EUID -ne 0 ]] || { echo "Bitte als normaler Benutzer starten."; exit 1; }

printf '%sSymlinks entfernen%s\n' "$B" "$N"
for entry in "${LINKS[@]}"; do
    src="$REPO/${entry%%|*}"; src="${src%/.}"
    dst="$HOME/${entry#*|}"
    if [[ -L $dst && "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]]; then
        rm "$dst"; ok "entfernt: ~/${entry#*|}"
    fi
done
rm -f "$HOME/.config/hypr/version.conf" 2>/dev/null || true

printf '%sBackup zurückspielen%s\n' "$B" "$N"
if [[ -d $BACKUP_ROOT ]]; then
    # ältestes Backup zuerst = Originalzustand vor der ersten Installation
    while IFS= read -r dir; do
        for entry in "${LINKS[@]}"; do
            rel="${entry#*|}"
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
if [[ -f $HOME/.icons/default/index.theme ]] && grep -q 'WhiteSur-cursors' "$HOME/.icons/default/index.theme"; then
    rm "$HOME/.icons/default/index.theme"; ok "Cursor-Default entfernt"
fi

printf '\n%sFertig.%s Pakete, Themes (~/.themes, ~/.local/share/icons) und /etc/portage/*/gentoo-rice bleiben erhalten.\n' "$G$B" "$N"

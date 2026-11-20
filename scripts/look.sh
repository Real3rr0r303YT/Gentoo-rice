#!/usr/bin/env bash
# Gentoo-rice – Look für Login-Screen + GRUB auf einmal wechseln (Hyprland/Rice bleiben)
# Nutzung: ./scripts/look.sh mac|blue|minecraft [--no-grub]
#   mac        Login wie macOS (große Uhr, Avatar, Passwort-Pille), GRUB im Mac-Bootpicker-Stil
#   blue       blauer Glas-Login, blaues GRUB
#   minecraft  Klötzchen-Login und -GRUB
# Copyright (C) 2026 3rr0r303YT – GPL-3.0-or-later
set -Eeuo pipefail
REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
LOOK=${1:-}
GRUB=1
[[ ${2:-} == --no-grub ]] && GRUB=0
case $LOOK in
    mac|macos|apple) SDDM_T=gentoo-rice-mac GRUB_T=mac ;;
    blue|blau)       SDDM_T=gentoo-rice GRUB_T=blue ;;
    minecraft|blocks) SDDM_T=gentoo-rice-blocks GRUB_T=blocks ;;
    *) sed -n '2,7p' "$0"; exit 1 ;;
esac

TOTAL=$((1 + GRUB)) STEP_LABEL=look
# shellcheck source=scripts/links.sh
source "$REPO/scripts/links.sh"
# shellcheck source=scripts/lib.sh
source "$REPO/scripts/lib.sh"

step "Login-Screen: $SDDM_T"
CONF=/etc/sddm.conf.d/10-gentoo-rice.conf
if [[ ! -f $CONF ]]; then
    warn "Login-Screen ist noch nicht eingerichtet – zuerst: ./scripts/login-screen.sh --theme $LOOK"
else
    for t in gentoo-rice gentoo-rice-blocks gentoo-rice-mac; do
        dst=/usr/share/sddm/themes/$t
        $SUDO rm -rf "$dst"
        $SUDO cp -r "$REPO/sddm/$t" "$dst"
        $SUDO ln -sfn "$LOGIN_STATE/sddm/theme.conf.user" "$dst/theme.conf.user"
    done
    $SUDO sed -i -E "s|^Current=.*|Current=$SDDM_T|" "$CONF"
    "$REPO/scripts/sddm-sync.sh" >/dev/null 2>&1 || true
    ok "Login-Screen-Theme: $SDDM_T (sichtbar beim nächsten Abmelden)"
fi

if ((GRUB)); then
    "$REPO/scripts/grub-setup.sh" --theme "$GRUB_T" || warn "GRUB-Theme fehlgeschlagen – einzeln: ./scripts/grub-setup.sh --theme $GRUB_T"
fi
print_problems

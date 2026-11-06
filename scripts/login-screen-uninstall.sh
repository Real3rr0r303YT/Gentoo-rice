#!/usr/bin/env bash
# Gentoo-rice – Login-Screen (SDDM) zurückbauen
#   - display-manager aus dem Runlevel entfernen
#   - alle von login-screen.sh geänderten Dateien aus dem Backup zurückspielen,
#     neu angelegte entfernen (laut Manifest)
#   - TTY1-Autostart (Hyprland) wiederherstellen
# Pakete (sddm, weston …) bleiben installiert.
# Copyright (C) 2026 3rr0r303YT – GPL-3.0-or-later
set -Eeuo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOTAL=4 STEP_LABEL=login
# shellcheck source=scripts/links.sh
source "$REPO/scripts/links.sh"
# shellcheck source=scripts/lib.sh
source "$REPO/scripts/lib.sh"

MANIFEST=$LOGIN_STATE/backup/manifest

printf '%s\n' "${B}Gentoo-rice${N} ${D}– Login-Screen entfernen${N}"

# ── 1. Runlevel ───────────────────────────────────────────
step "display-manager aus dem Runlevel entfernen"
if rc-update show default 2>/dev/null | grep -w display-manager >/dev/null; then
    $SUDO rc-update del display-manager default >>"$LOG" 2>&1 && ok "rc-update del display-manager default"
else
    info "display-manager war nicht im Runlevel default"
fi

# ── 2. Dateien zurückspielen ──────────────────────────────
step "Geänderte Dateien zurückspielen"
if [[ -f $MANIFEST ]]; then
    # pro Pfad zählt der erste Eintrag (= Zustand vor der ersten Einrichtung)
    while read -r kind backup path; do
        [[ -n ${path:-} ]] || continue
        case $kind in
            N)
                if [[ -e $path || -L $path ]]; then $SUDO rm -rf "$path"; ok "entfernt: $path"; fi ;;
            M)
                if [[ -e $backup$path || -L $backup$path ]]; then
                    $SUDO rm -rf "$path"
                    $SUDO mkdir -p "$(dirname "$path")"
                    $SUDO cp -a "$backup$path" "$path"
                    ok "wiederhergestellt: $path"
                else
                    warn "Backup fehlt: $backup$path"
                fi ;;
        esac
    done < <(awk '!seen[$3]++' "$MANIFEST")
    $SUDO mv "$MANIFEST" "$MANIFEST.restored-$(date +%Y-%m-%d_%H-%M-%S)"
else
    warn "kein Manifest gefunden ($MANIFEST) – nichts zurückzuspielen"
fi
$SUDO rm -rf "$LOGIN_STATE/sddm"
$SUDO rm -f "$LOGIN_MARKER"

# ── 3. TTY1-Autostart ─────────────────────────────────────
step "TTY1-Autostart wiederherstellen"
touch "$HOME/.bash_profile"
if grep -qF "$PROFILE_BEGIN" "$HOME/.bash_profile"; then
    info "Autostart ist bereits in ~/.bash_profile"
else
    printf '\n%s\n' "$PROFILE_SNIPPET" >> "$HOME/.bash_profile"
    ok "Hyprland startet wieder nach dem Login auf TTY1"
fi

# ── 4. Fertig ─────────────────────────────────────────────
step "Fertig"
ok "Login-Screen entfernt – wirksam nach einem Neustart (sudo reboot)"
info "SDDM läuft bis zum Neustart weiter; Pakete bleiben installiert (sudo emerge --depclean entfernt sie bei Bedarf)."

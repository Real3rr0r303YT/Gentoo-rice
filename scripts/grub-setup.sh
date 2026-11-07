#!/usr/bin/env bash
# Gentoo-rice – GRUB-Bootmenü: sichtbares Menü mit Auswahlzeit + Windows-Eintrag (os-prober)
# Copyright (C) 2026 3rr0r303YT – GPL-3.0-or-later
#
# Nutzung: ./scripts/grub-setup.sh [--timeout SEKUNDEN]   (Standard: 5)
#          ./scripts/grub-setup.sh --restore               (Original von /etc/default/grub zurück)
set -Eeuo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TIMEOUT=5 RESTORE=0
while (($#)); do
    case $1 in
        --timeout) TIMEOUT=${2:-}; shift ;;
        --timeout=*) TIMEOUT=${1#*=} ;;
        --restore) RESTORE=1 ;;
        -h|--help) sed -n '2,7p' "$0"; exit 0 ;;
        *) printf 'Unbekannte Option: %s\n' "$1" >&2; exit 1 ;;
    esac
    shift
done
[[ $TIMEOUT =~ ^[0-9]+$ ]] || { echo "--timeout braucht eine Zahl (Sekunden)" >&2; exit 1; }

TOTAL=4 STEP_LABEL=grub
# shellcheck source=scripts/lib.sh
source "$REPO/scripts/lib.sh"

CFG=/etc/default/grub
ORIG=/etc/default/grub.gentoo-rice.orig

# Ausgabedatei von grub-mkconfig finden (Gentoo: /boot/grub/grub.cfg)
grub_cfg() {
    local d
    for d in /boot/grub /boot/grub2 /efi/grub /boot/efi/grub; do
        if $SUDO test -d "$d"; then echo "$d/grub.cfg"; return 0; fi
    done
    return 1
}
mkconfig() {
    local out
    out=$(grub_cfg) || die "Kein GRUB-Verzeichnis gefunden (/boot/grub). Ist /boot gemountet? (sudo mount /boot)"
    command -v grub-mkconfig >/dev/null || die "grub-mkconfig fehlt (sys-boot/grub)."
    info "grub-mkconfig -o $out"
    local tmp
    tmp=$(mktemp)
    if ! $SUDO grub-mkconfig -o "$out" >"$tmp" 2>&1; then
        cat "$tmp" >> "$LOG"; rm -f "$tmp"
        die "grub-mkconfig fehlgeschlagen – Details im Log. Altes Bootmenü bleibt unverändert."
    fi
    cat "$tmp" >> "$LOG"
    grep -iE 'found|warn' "$tmp" | sed 's/^/  · /' || true
    rm -f "$tmp"
    if $SUDO grep -qiE "menuentry ['\"]?Windows" "$out"; then ok "Windows-Eintrag im Bootmenü"
    else info "Kein Windows gefunden (normal, wenn nur Gentoo installiert ist)"; fi
    ok "Bootmenü geschrieben: $out"
}

[[ -f $CFG ]] || die "$CFG fehlt – GRUB (sys-boot/grub) ist nicht installiert oder nicht der Bootloader."

if ((RESTORE)); then
    step "Original wiederherstellen"
    [[ -f $ORIG ]] || die "Kein Backup ($ORIG) vorhanden."
    $SUDO cp -a "$ORIG" "$CFG"
    ok "$CFG aus $ORIG wiederhergestellt"
    step "Bootmenü neu erzeugen"
    mkconfig
    exit 0
fi

printf '%s\n' "${B}Gentoo-rice${N} ${D}– GRUB: $TIMEOUT s Auswahlzeit, Windows im Menü${N}"

# ── 1. Backup ─────────────────────────────────────────────
step "Backup von $CFG"
if [[ -f $ORIG ]]; then
    info "Original-Backup existiert bereits: $ORIG"
else
    $SUDO cp -a "$CFG" "$ORIG"
    ok "gesichert: $ORIG"
fi
$SUDO cp -a "$CFG" "$CFG.bak-$(date +%Y-%m-%d_%H-%M-%S)"

# ── 2. os-prober (Windows erkennen) ───────────────────────
step "os-prober für den Windows-Eintrag"
emerge_pkgs sys-boot/os-prober
if command -v os-prober >/dev/null; then ok "os-prober vorhanden"; else warn "os-prober fehlt – Windows erscheint evtl. nicht im Menü"; fi

# ── 3. /etc/default/grub anpassen ─────────────────────────
step "Einstellungen"
set_kv() { # set_kv <SCHLÜSSEL> <WERT> – vorhandene (auch auskommentierte) Zeile ersetzen, sonst anhängen
    local k=$1 v=$2
    if $SUDO grep -qE "^[#[:space:]]*$k=" "$CFG"; then
        $SUDO sed -i -E "s|^[#[:space:]]*$k=.*|$k=$v|" "$CFG"
    else
        echo "$k=$v" | $SUDO tee -a "$CFG" >/dev/null
    fi
    info "$k=$v"
}
set_kv GRUB_TIMEOUT "$TIMEOUT"
set_kv GRUB_TIMEOUT_STYLE menu
set_kv GRUB_DISABLE_OS_PROBER false
# Nur eine Zeile pro Schlüssel behalten (falls doppelt vorhanden)
for k in GRUB_TIMEOUT GRUB_TIMEOUT_STYLE GRUB_DISABLE_OS_PROBER; do
    n=$($SUDO grep -cE "^$k=" "$CFG" || true)
    if ((n > 1)); then $SUDO sed -i -E "0,/^$k=/! { /^$k=/d }" "$CFG"; fi
done
ok "$CFG angepasst"

# ── 4. Bootmenü erzeugen ──────────────────────────────────
step "Bootmenü neu erzeugen"
mkconfig

print_problems
printf '\n%sFertig:%s Beim nächsten Start zeigt GRUB das Menü %s Sekunden lang (Pfeiltasten + Enter).\n' "$G$B" "$N" "$TIMEOUT"
printf '%sRückgängig:%s ./scripts/grub-setup.sh --restore\n' "$D" "$N"

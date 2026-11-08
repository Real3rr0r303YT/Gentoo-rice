#!/usr/bin/env bash
# Gentoo-rice – Virenschutz mit ClamAV
#   setup   ClamAV + inotify-tools installieren, Signaturen laden, Dienste (freshclam, clamd) aktivieren
#   watch   Wächter: neue Dateien in Downloads, Minecraft- und CurseForge-Ordnern sofort prüfen,
#           Funde in die Quarantäne verschieben (startet automatisch mit Hyprland)
#   update  installieren, falls nötig – sonst ClamAV + Signaturen aktualisieren
#   scan    Ordner prüfen (Standard: ~), Funde in die Quarantäne
# Copyright (C) 2026 3rr0r303YT – GPL-3.0-or-later
set -uo pipefail

REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
QUAR="$HOME/.local/share/gentoo-rice/quarantine"
AVLOG="$HOME/.cache/gentoo-rice/antivirus.log"
WATCH_DIRS=(
    "$HOME/Downloads"
    "$HOME/.minecraft"
    "$HOME/.var/app/com.mojang.Minecraft"
    "$HOME/.var/app/com.overwolf.curseforge"
    "$HOME/.var/app/org.vinegarhq.Sober"
    "$HOME/.local/share/PrismLauncher"
    "$HOME/curseforge"
)
# In Spiele-Ordnern nur ausführbare/Mod-Dateien prüfen (Spielstände ändern sich ständig)
RISKY='\.(jar|zip|rar|7z|exe|msi|dll|bat|cmd|ps1|scr|vbs|js|sh|py|appimage|deb|rpm|so|bin|run)$'

mkdir -p "$QUAR" "$(dirname "$AVLOG")"
chmod 700 "$QUAR" 2>/dev/null || true

notify() { if command -v notify-send >/dev/null; then notify-send -a Virenschutz "$@" || true; fi; }
log() { printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$AVLOG"; }

# check_file <datei> – 0 = sauber/unbekannt, 1 = Fund (verschoben)
check_file() {
    local f=$1 out rc dest
    [[ -f $f ]] || return 0
    if pgrep -x clamd >/dev/null; then
        out=$(clamdscan --fdpass --no-summary --infected "$f" 2>&1); rc=$?
    else
        out=$(clamscan --no-summary --infected "$f" 2>&1); rc=$?
    fi
    [[ $rc -eq 1 ]] || return 0
    dest="$QUAR/$(date +%Y%m%d-%H%M%S)_$(basename "$f")"
    mv -f "$f" "$dest" && chmod 000 "$dest"
    log "FUND: $f → $dest :: ${out//$'\n'/ }"
    notify -u critical -i security-high "Schadsoftware gefunden!" \
        "$(basename "$f") wurde in die Quarantäne verschoben."$'\n'"${out##*: }"
    return 1
}

watch() {
    command -v inotifywait >/dev/null || { echo "inotifywait fehlt (./scripts/antivirus.sh setup)" >&2; exit 0; }
    command -v clamscan >/dev/null || { echo "ClamAV fehlt (./scripts/antivirus.sh setup)" >&2; exit 0; }
    # nur eine Instanz
    exec 9>"$HOME/.cache/gentoo-rice/antivirus.lock"
    flock -n 9 || exit 0
    mkdir -p "$HOME/Downloads"
    local dirs=() d f
    for d in "${WATCH_DIRS[@]}"; do [[ -d $d ]] && dirs+=("$d"); done
    log "Wächter gestartet: ${dirs[*]}"
    inotifywait -m -r -q -e close_write -e moved_to --format '%w%f' "${dirs[@]}" 2>>"$AVLOG" |
        while IFS= read -r f; do
            case $f in
                "$HOME/Downloads/"*) [[ $f == *.part || $f == *.crdownload ]] && continue ;;
                *) [[ ${f,,} =~ $RISKY ]] || continue ;;
            esac
            check_file "$f" || true
        done
}

scan() {
    local target=${1:-$HOME} rc
    command -v clamscan >/dev/null || { echo "ClamAV fehlt – zuerst: ./scripts/antivirus.sh setup" >&2; exit 1; }
    echo "Prüfe $target … (Funde → $QUAR)"
    if pgrep -x clamd >/dev/null; then
        clamdscan --fdpass --multiscan --infected --move="$QUAR" "$target"; rc=$?
    else
        clamscan -r --infected --move="$QUAR" --exclude-dir="^$QUAR" "$target"; rc=$?
    fi
    case $rc in
        0) echo "✔ Nichts gefunden."; notify "Virenscan" "Nichts gefunden in $target" ;;
        1) echo "✘ Funde in die Quarantäne verschoben: $QUAR"; log "Scan $target: Funde"
           notify -u critical "Virenscan" "Schadsoftware gefunden – in Quarantäne verschoben" ;;
        *) echo "! Scan mit Fehlern (Code $rc)" ;;
    esac
    return 0
}

setup() {
    TOTAL=3 STEP_LABEL=av KW_FILE=/etc/portage/package.accept_keywords/gentoo-rice-av
    # shellcheck source=scripts/lib.sh
    source "$REPO/scripts/lib.sh"
    printf '%s\n' "${B}Gentoo-rice${N} ${D}– Virenschutz (ClamAV)${N}"

    step "ClamAV installieren"
    as_dir package.accept_keywords
    emerge_pkgs app-antivirus/clamav sys-fs/inotify-tools
    emerge_pkgs --optional app-antivirus/clamtk
    installed app-antivirus/clamav || die "ClamAV konnte nicht installiert werden – Details im Log."

    step "Virensignaturen (freshclam)"
    local f
    for f in /etc/freshclam.conf /etc/clamd.conf; do   # Beispiel-Sperre entfernen, falls vorhanden
        if [[ -f $f ]] && grep -q '^Example' "$f"; then $SUDO sed -i 's/^Example/#Example/' "$f"; fi
    done
    if $SUDO freshclam >>"$LOG" 2>&1; then ok "Signaturen aktuell"
    else warn "freshclam mit Fehlern (Netz?) – der Dienst versucht es später erneut"; fi

    step "Dienste"
    local s
    for s in freshclam clamd; do
        if [[ -x /etc/init.d/$s ]]; then
            $SUDO rc-update add "$s" default >>"$LOG" 2>&1 || true
            $SUDO rc-service "$s" start >>"$LOG" 2>&1 || true
            ok "$s läuft und startet beim Booten"
        else
            warn "OpenRC-Dienst $s nicht gefunden"
        fi
    done
    info "Echtzeit-Wächter startet mit Hyprland (Downloads, Minecraft, CurseForge, Sober)"
    info "Quarantäne: $QUAR · Log: $AVLOG"
    pgrep -f "antivirus.sh watch" >/dev/null || ( setsid "$REPO/scripts/antivirus.sh" watch >/dev/null 2>&1 & )
    print_problems
}

update() {
    if ! command -v clamscan >/dev/null; then setup; return; fi
    TOTAL=2 STEP_LABEL=av KW_FILE=/etc/portage/package.accept_keywords/gentoo-rice-av
    # shellcheck source=scripts/lib.sh
    source "$REPO/scripts/lib.sh"
    printf '%s\n' "${B}Gentoo-rice${N} ${D}– Virenschutz aktualisieren${N}"
    step "ClamAV-Programm"
    if $SUDO "${EMERGE_BASE[@]}" --oneshot --update --getbinpkg --binpkg-respect-use=y --quiet-build=y \
        app-antivirus/clamav >>"$LOG" 2>&1; then ok "ClamAV aktuell ($(clamscan --version 2>/dev/null | cut -d/ -f1))"
    else warn "ClamAV-Update mit Fehlern – Details im Log"; fi
    step "Virensignaturen"
    if pgrep -x freshclam >/dev/null; then $SUDO rc-service freshclam stop >>"$LOG" 2>&1 || true; fi
    if $SUDO freshclam; then ok "Signaturen aktuell"; else warn "freshclam mit Fehlern (Netz?)"; fi
    local s
    for s in freshclam clamd; do
        if [[ -x /etc/init.d/$s ]]; then $SUDO rc-service "$s" restart >>"$LOG" 2>&1 || $SUDO rc-service "$s" start >>"$LOG" 2>&1 || true; fi
    done
    pgrep -f "antivirus.sh watch" >/dev/null || ( setsid "$REPO/scripts/antivirus.sh" watch >/dev/null 2>&1 & )
    ok "Wächter läuft"
    print_problems
}

case ${1:-} in
    setup)  setup ;;
    update) update ;;
    watch) watch ;;
    scan)  scan "${2:-$HOME}" ;;
    *) printf 'Nutzung: %s setup|update|watch|scan [ordner]\n' "$0" >&2; exit 1 ;;
esac

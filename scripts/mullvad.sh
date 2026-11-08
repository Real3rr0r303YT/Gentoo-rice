#!/usr/bin/env bash
# Gentoo-rice – Mullvad VPN starten/reparieren
#   open   App öffnen (startet vorher den Dienst, falls nötig)  ← Rice-Menü
#   setup  OpenRC-Dienst einrichten/starten (sudo)               ← apps.sh
#   status Diagnose ausgeben
# Copyright (C) 2026 3rr0r303YT – GPL-3.0-or-later
set -uo pipefail
DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
MLOG="$HOME/.cache/gentoo-rice/mullvad.log"
INIT=/etc/init.d/mullvad-daemon
mkdir -p "$(dirname "$MLOG")"

notify() { if command -v notify-send >/dev/null; then notify-send -a "Mullvad VPN" "$@" || true; fi; }

find_bin() { # find_bin <name…> – erstes vorhandenes Programm (PATH oder /opt/Mullvad VPN)
    local n f
    for n in "$@"; do
        if command -v "$n" >/dev/null; then command -v "$n"; return 0; fi
        for f in "/opt/Mullvad VPN/$n" "/opt/Mullvad VPN/resources/$n" /opt/mullvad*/"$n" /opt/mullvad*/resources/"$n" "/usr/lib/mullvad-vpn/$n"; do
            if [[ -x $f ]]; then echo "$f"; return 0; fi
        done
    done
    return 1
}

daemon_running() { pgrep -x mullvad-daemon >/dev/null; }

setup() {
    local daemon svc="" s
    daemon=$(find_bin mullvad-daemon) || { echo "mullvad-daemon nicht gefunden – ist Mullvad installiert? (./scripts/apps.sh)"; return 1; }
    for s in mullvad-daemon mullvadvpn-daemon mullvad; do
        if [[ -x /etc/init.d/$s ]]; then svc=$s; break; fi
    done
    if [[ -z $svc ]]; then
        echo "Lege OpenRC-Dienst an: $INIT"
        sudo tee "$INIT" >/dev/null <<INIT_EOF
#!/sbin/openrc-run
# Gentoo-rice: Mullvad-VPN-Dienst (das Paket bringt keinen OpenRC-Dienst mit)
description="Mullvad VPN daemon"
command="$daemon"
command_args="-v --disable-stdout-timestamps"
command_background=true
pidfile="/run/\${RC_SVCNAME}.pid"
output_log="/var/log/mullvad-daemon.log"
error_log="/var/log/mullvad-daemon.log"
depend() {
    need net
    before display-manager
}
INIT_EOF
        sudo chmod 0755 "$INIT"
        svc=mullvad-daemon
    fi
    sudo rc-update add "$svc" default >/dev/null 2>&1 || true
    sudo rc-service "$svc" restart >/dev/null 2>&1 || sudo rc-service "$svc" start || true
    sleep 2
    if daemon_running; then echo "✔ Mullvad-Dienst ($svc) läuft und startet beim Booten"
    else echo "✘ Dienst startet nicht – Log: sudo tail -30 /var/log/mullvad-daemon.log"; return 1; fi
}

launch_gui() {
    local gui
    gui=$(find_bin mullvad-vpn mullvad-gui) || return 1
    echo "--- $(date '+%F %T') $gui" >> "$MLOG"
    "$gui" >>"$MLOG" 2>&1 &
    local pid=$!
    sleep 4
    if kill -0 "$pid" 2>/dev/null; then return 0; fi
    # Electron ohne setuid-Sandbox (häufig bei umgepackten .deb-Paketen)
    echo "--- Neustart mit --no-sandbox" >> "$MLOG"
    "$gui" --no-sandbox >>"$MLOG" 2>&1 &
    pid=$!
    sleep 4
    kill -0 "$pid" 2>/dev/null
}

open() {
    if ! find_bin mullvad-vpn mullvad-gui mullvad-daemon >/dev/null; then
        notify -u critical "Nicht installiert" "Super+D → Apps aktualisieren oder: ./scripts/apps.sh"
        exit 1
    fi
    if ! daemon_running; then
        # Dienst braucht sudo → kurz ein Terminal öffnen
        exec kitty --class rice-float sh -c "echo 'Mullvad-Dienst starten (sudo-Passwort):'; '$DIR/mullvad.sh' setup && '$DIR/mullvad.sh' gui; sleep 2"
    fi
    gui_or_hint
}

gui_or_hint() {
    if launch_gui; then exit 0; fi
    notify -u critical "Mullvad startet nicht" "Details: ~/.cache/gentoo-rice/mullvad.log – im Terminal: mullvad status / mullvad connect"
    exit 1
}

status() {
    echo "GUI:    $(find_bin mullvad-vpn mullvad-gui || echo fehlt)"
    echo "Daemon: $(find_bin mullvad-daemon || echo fehlt)"
    echo "CLI:    $(find_bin mullvad || echo fehlt)"
    if daemon_running; then echo "Dienst: läuft"; else echo "Dienst: läuft NICHT"; fi
    local f
    for f in /etc/init.d/*mullvad*; do if [[ -e $f ]]; then echo "OpenRC: $f"; fi; done
    if command -v mullvad >/dev/null; then mullvad status 2>&1 | sed 's/^/VPN:    /'; fi
    echo "--- letzte GUI-Meldungen:"; tail -15 "$MLOG" 2>/dev/null
}

case ${1:-open} in
    open)   open ;;
    gui)    gui_or_hint ;;
    setup)  setup ;;
    status) status ;;
    *) echo "Nutzung: $0 [open|setup|status]" >&2; exit 1 ;;
esac

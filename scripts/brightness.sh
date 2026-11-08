#!/usr/bin/env bash
# Gentoo-rice – Bildschirmhelligkeit (Waybar-Modul, Helligkeitstasten)
#   Laptop-Display: brightnessctl · externer Monitor: DDC/CI über ddcutil
# Nutzung: brightness.sh status|up|down|set <0-100>|click|setup
# Copyright (C) 2026 3rr0r303YT – GPL-3.0-or-later
set -uo pipefail
CACHE="$HOME/.cache/rice/brightness"
LOCK="$HOME/.cache/rice/brightness.lock"
STEP=5
mkdir -p "$(dirname "$CACHE")"

has_backlight() { compgen -G "/sys/class/backlight/*" >/dev/null && command -v brightnessctl >/dev/null; }
has_ddc() { command -v ddcutil >/dev/null && compgen -G "/dev/i2c-*" >/dev/null; }

get() {
    if has_backlight; then
        brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '%'
    elif has_ddc; then
        if [[ -s $CACHE ]]; then cat "$CACHE"; return; fi
        local cur max v
        read -r _ _ _ cur max < <(ddcutil getvcp 10 --brief 2>/dev/null) || return 1
        [[ ${cur:-} =~ ^[0-9]+$ && ${max:-} =~ ^[0-9]+$ && $max -gt 0 ]] || return 1
        v=$((cur * 100 / max)); echo "$v" > "$CACHE"; echo "$v"
    else
        return 1
    fi
}

apply() { # apply <0-100>
    local v=$1
    ((v < 0)) && v=0; ((v > 100)) && v=100
    if has_backlight; then
        brightnessctl -q set "${v}%"
    elif has_ddc; then
        echo "$v" > "$CACHE"
        # DDC ist langsam: im Hintergrund nachziehen, bis der letzte Wert gesetzt ist
        (
            flock -n 9 || exit 0
            local done=-1 want
            while want=$(cat "$CACHE") && [[ $want != "$done" ]]; do
                ddcutil setvcp 10 "$want" --noverify >/dev/null 2>&1 || break
                done=$want
            done
        ) 9>"$LOCK" &
    fi
    pkill -RTMIN+8 -x waybar 2>/dev/null || true
}

status() {
    local v
    if v=$(get) && [[ $v =~ ^[0-9]+$ ]]; then
        printf '{"text":"%s%%","percentage":%s,"tooltip":"Helligkeit: %s%% – Mausrad zum Ändern"}\n' "$v" "$v" "$v"
    else
        printf '{"text":"--","percentage":0,"class":"off","tooltip":"Helligkeit: noch nicht eingerichtet – klicken zum Einrichten"}\n'
    fi
}

setup() { # externer Monitor: ddcutil + i2c-dev (sudo)
    REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
    TOTAL=1 STEP_LABEL=hell
    # shellcheck source=scripts/lib.sh
    source "$REPO/scripts/lib.sh"
    step "Helligkeit für externe Monitore (DDC/CI)"
    emerge_pkgs app-misc/ddcutil app-misc/brightnessctl
    echo i2c-dev | write_root /etc/modules-load.d/i2c-dev.conf
    $SUDO modprobe i2c-dev 2>/dev/null || true
    if getent group i2c >/dev/null; then $SUDO gpasswd -a "$(id -un)" i2c >/dev/null 2>&1 || true; fi
    if command -v ddcutil >/dev/null && ddcutil detect --brief 2>/dev/null | grep -q '^Display'; then
        ok "Monitor per DDC/CI steuerbar"
    else
        warn "Kein DDC/CI-Monitor erkannt – im Monitor-Menü 'DDC/CI' einschalten; nach Neuanmeldung erneut testen"
    fi
    rm -f "$CACHE"
    pkill -RTMIN+8 -x waybar 2>/dev/null || true
    print_problems
    echo "Falls die Helligkeit noch '--' zeigt: einmal ab- und wieder anmelden."
}

case ${1:-status} in
    status) status ;;
    up)     cur=$(get) || exit 0; apply $((cur + STEP)) ;;
    down)   cur=$(get) || exit 0; apply $((cur - STEP)) ;;
    set)    [[ ${2:-} =~ ^[0-9]+$ ]] && apply "$2" ;;
    click)  # Waybar-Klick: 100 % – oder Einrichtung, falls noch nichts steuerbar ist
        if get >/dev/null 2>&1; then apply 100
        else exec kitty --class rice-float --hold "$(readlink -f "${BASH_SOURCE[0]}")" setup; fi ;;
    setup)  setup ;;
    *) echo "Nutzung: $0 status|up|down|set <0-100>|setup" >&2; exit 1 ;;
esac

#!/usr/bin/env bash
# Gentoo-rice – Bildschirmhelligkeit (Waybar-Modul, Helligkeitstasten)
#   1. Laptop-Display: brightnessctl
#   2. externer Monitor: DDC/CI über ddcutil (echte Monitor-Helligkeit)
#   3. Fallback: hyprsunset (Software-Dimmen über Gamma – geht immer, nur dunkler)
# Nutzung: brightness.sh status|up|down|set <0-100>|click|restore|setup|diag
# Copyright (C) 2026 3rr0r303YT – GPL-3.0-or-later
set -uo pipefail
STATE="$HOME/.cache/rice"
CACHE="$STATE/brightness"
MODE_FILE="$STATE/brightness.mode"
LOCK="$STATE/brightness.lock"
STEP=5
SOFT_MIN=20   # Software-Dimmen nicht ganz schwarz
mkdir -p "$STATE"

ddc_read() { # → Prozent oder Fehler
    local cur max
    read -r _ _ _ cur max < <(timeout 5 ddcutil getvcp 10 --brief 2>/dev/null) || return 1
    [[ ${cur:-} =~ ^[0-9]+$ && ${max:-} =~ ^[0-9]+$ && $max -gt 0 ]] || return 1
    echo $((cur * 100 / max))
}

# Modus einmal bestimmen und merken (DDC-Prüfung dauert)
mode() {
    if [[ -s $MODE_FILE ]]; then cat "$MODE_FILE"; return; fi
    local m=none v
    if compgen -G "/sys/class/backlight/*" >/dev/null && command -v brightnessctl >/dev/null; then
        m=backlight
    elif command -v ddcutil >/dev/null && v=$(ddc_read); then
        m=ddc; echo "$v" > "$CACHE"
    elif command -v hyprsunset >/dev/null; then
        m=soft
    fi
    [[ $m == none ]] || echo "$m" > "$MODE_FILE"
    echo "$m"
}

get() {
    case $(mode) in
        backlight) brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '%' ;;
        ddc|soft)  if [[ -s $CACHE ]]; then cat "$CACHE"; else echo 100; fi ;;
        *) return 1 ;;
    esac
}

soft_apply() { # soft_apply <prozent>
    if ! pgrep -x hyprsunset >/dev/null; then
        (hyprsunset --identity >/dev/null 2>&1 &) || (hyprsunset >/dev/null 2>&1 &)
        sleep 0.4
    fi
    hyprctl hyprsunset gamma "$1" >/dev/null 2>&1 || true
}

apply() { # apply <0-100>
    local v=$1 m
    m=$(mode)
    ((v > 100)) && v=100
    if [[ $m == soft ]]; then ((v < SOFT_MIN)) && v=$SOFT_MIN; else ((v < 0)) && v=0; fi
    case $m in
        backlight) brightnessctl -q set "${v}%" ;;
        ddc)
            echo "$v" > "$CACHE"
            # DDC ist langsam: im Hintergrund nachziehen, bis der letzte Wert gesetzt ist
            (
                flock -n 9 || exit 0
                done=-1
                while want=$(cat "$CACHE") && [[ $want != "$done" ]]; do
                    ddcutil setvcp 10 "$want" --noverify >/dev/null 2>&1 || break
                    done=$want
                done
            ) 9>"$LOCK" & ;;
        soft) echo "$v" > "$CACHE"; soft_apply "$v" ;;
        *) return 1 ;;
    esac
    pkill -RTMIN+8 -x waybar 2>/dev/null || true
}

status() {
    local v m
    m=$(mode)
    if v=$(get) && [[ $v =~ ^[0-9]+$ ]]; then
        local how="Monitor"
        [[ $m == soft ]] && how="Software-Dimmen"
        [[ $m == backlight ]] && how="Display"
        printf '{"text":"%s%%","percentage":%s,"class":"%s","tooltip":"Helligkeit: %s%% (%s) – Mausrad zum Ändern"}\n' "$v" "$v" "$m" "$v" "$how"
    else
        printf '{"text":"--","percentage":0,"class":"off","tooltip":"Helligkeit: noch nicht eingerichtet – klicken zum Einrichten"}\n'
    fi
}

diag() {
    echo "Modus:      $(rm -f "$MODE_FILE"; mode)"
    echo "Backlight:  $(compgen -G '/sys/class/backlight/*' | tr '\n' ' ')"
    echo "i2c:        $(compgen -G '/dev/i2c-*' | tr '\n' ' ')"
    echo "Gruppen:    $(id -nG)"
    echo "hyprsunset: $(command -v hyprsunset || echo fehlt)"
    if command -v ddcutil >/dev/null; then
        echo "--- ddcutil detect"; timeout 20 ddcutil detect 2>&1 | head -20
        echo "--- ddcutil getvcp 10"; timeout 10 ddcutil getvcp 10 2>&1 | head -5
    else
        echo "ddcutil fehlt"
    fi
}

setup() { # ddcutil + i2c-dev + hyprsunset (sudo)
    REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
    TOTAL=1 STEP_LABEL=hell
    # shellcheck source=scripts/lib.sh
    source "$REPO/scripts/lib.sh"
    step "Helligkeit (DDC/CI für externe Monitore, sonst Software-Dimmen)"
    emerge_pkgs app-misc/ddcutil app-misc/brightnessctl
    emerge_pkgs --optional gui-apps/hyprsunset
    echo i2c-dev | write_root /etc/modules-load.d/i2c-dev.conf
    $SUDO modprobe i2c-dev 2>/dev/null || true
    if ! getent group i2c >/dev/null; then $SUDO groupadd -r i2c 2>/dev/null || true; fi
    $SUDO gpasswd -a "$(id -un)" i2c >/dev/null 2>&1 || true
    # i2c-Geräte für die Gruppe i2c freigeben (falls die udev-Regel von ddcutil fehlt)
    echo 'KERNEL=="i2c-[0-9]*", GROUP="i2c", MODE="0660"' | write_root /etc/udev/rules.d/45-gentoo-rice-i2c.rules
    $SUDO udevadm control --reload-rules >/dev/null 2>&1 || true
    $SUDO udevadm trigger --subsystem-match=i2c-dev >/dev/null 2>&1 || true
    rm -f "$MODE_FILE" "$CACHE"
    if command -v ddcutil >/dev/null && $SUDO timeout 20 ddcutil getvcp 10 >/dev/null 2>&1; then
        ok "Monitor per DDC/CI steuerbar (echte Helligkeit) – nach Neuanmeldung aktiv"
    elif command -v hyprsunset >/dev/null; then
        warn "Monitor antwortet nicht per DDC/CI → Software-Dimmen (hyprsunset)"
        info "Für echte Helligkeit: im Monitor-Menü 'DDC/CI' einschalten, dann erneut einrichten"
    else
        warn "Weder DDC/CI noch hyprsunset verfügbar – Details: ./scripts/brightness.sh diag"
    fi
    pkill -RTMIN+8 -x waybar 2>/dev/null || true
    print_problems
    echo "Danach einmal ab- und wieder anmelden."
}

case ${1:-status} in
    status)  status ;;
    up)      cur=$(get) || exit 0; apply $((cur + STEP)) ;;
    down)    cur=$(get) || exit 0; apply $((cur - STEP)) ;;
    set)     [[ ${2:-} =~ ^[0-9]+$ ]] && apply "$2" ;;
    restore) rm -f "$MODE_FILE"; if [[ $(mode) == soft && -s $CACHE ]]; then soft_apply "$(cat "$CACHE")"; fi ;;
    click)   # Waybar-Klick: 100 % – oder Einrichtung, falls noch nichts steuerbar ist
        if get >/dev/null 2>&1; then apply 100
        else exec kitty --class rice-float --hold "$(readlink -f "${BASH_SOURCE[0]}")" setup; fi ;;
    setup)   setup ;;
    diag)    diag ;;
    *) echo "Nutzung: $0 status|up|down|set <0-100>|click|restore|setup|diag" >&2; exit 1 ;;
esac

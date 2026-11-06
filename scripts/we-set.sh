#!/usr/bin/env bash
# Gentoo-rice – Wallpaper-Engine-Wallpaper setzen (linux-wallpaperengine)
# Nutzung: we-set.sh <Workshop-ID|Ordner> [--quiet] | restore | stop
set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"
DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=scripts/we-lib.sh
source "$DIR/we-lib.sh"
mkdir -p "$WE_STATE"
LOG="$WE_STATE/linux-wallpaperengine.log"

notify() { command -v notify-send >/dev/null && notify-send -a "Wallpaper Engine" "$@" || true; }
fail() { # fail <meldung> [vorschau] – Fehler melden, auf swww mit Vorschaubild zurückfallen
    notify -u critical "Wallpaper Engine" "$1"
    echo "Fehler: $1" >&2
    [[ -n ${2:-} && -f ${2:-} ]] && "$DIR/wallpaper.sh" fallback "$2"
    exit 1
}

monitors() {
    hyprctl monitors -j 2>/dev/null | python3 -c 'import json,sys; [print(m["name"]) for m in json.load(sys.stdin)]' 2>/dev/null
}

set_we() {
    local target=$1 quiet=${2:-} dir assets pid mons=() args=() m
    we_load_config
    dir=$(we_resolve "$target") || fail "Wallpaper nicht gefunden: $target (Workshop-ID oder Ordner)"
    we_info "$dir"
    [[ -n $WE_PREVIEW ]] || WE_PREVIEW=""

    # Merken (für Neustart)
    printf 'we\n' > "$WE_STATE/mode"
    printf '%s\n' "$dir" > "$WE_STATE/we"

    # Farben aus dem Vorschaubild
    [[ -n $WE_PREVIEW ]] && "$DIR/wallpaper.sh" colors-from "$WE_PREVIEW"

    [[ -x $WE_BIN ]] || command -v linux-wallpaperengine >/dev/null ||
        fail "linux-wallpaperengine ist nicht installiert (./install.sh --we)" "$WE_PREVIEW"
    assets=$(we_assets_dir) ||
        fail "Wallpaper-Engine-Assets nicht gefunden – Wallpaper Engine in Steam installieren" "$WE_PREVIEW"
    mapfile -t mons < <(monitors)
    ((${#mons[@]})) || fail "Keine Monitore gefunden (läuft Hyprland?)" "$WE_PREVIEW"

    # Alte Hintergründe beenden
    we_stop
    pkill -x mpvpaper 2>/dev/null || true
    for b in awww swww; do command -v "$b" >/dev/null && "$b" kill >/dev/null 2>&1; done
    pkill -x swww-daemon 2>/dev/null || true
    pkill -x awww-daemon 2>/dev/null || true

    args=(--assets-dir "$assets" --fps "${WE_FPS:-30}" --scaling "${WE_SCALING:-fill}")
    [[ ${WE_SILENT:-1} == 1 ]] && args+=(--silent)
    [[ ${WE_AUTOMUTE:-1} == 0 ]] && args+=(--noautomute)
    for m in "${mons[@]}"; do args+=(--screen-root "$m" --bg "$dir"); done
    # shellcheck disable=SC2206
    [[ -n ${WE_EXTRA_ARGS:-} ]] && args+=($WE_EXTRA_ARGS)

    {
        echo "=== $(date '+%F %T') ${WE_TITLE:-} ($dir)"
        echo "linux-wallpaperengine ${args[*]}"
    } > "$LOG"
    if [[ -x $WE_BIN ]]; then setsid "$WE_BIN" "${args[@]}" >>"$LOG" 2>&1 < /dev/null &
    else setsid linux-wallpaperengine "${args[@]}" >>"$LOG" 2>&1 < /dev/null &
    fi
    pid=$!
    echo "$pid" > "$WE_STATE/we.pid"
    sleep 3
    if ! kill -0 "$pid" 2>/dev/null; then
        fail "linux-wallpaperengine konnte '${WE_TITLE:-$dir}' nicht starten (Log: ${LOG/#$HOME/\~})" "$WE_PREVIEW"
    fi

    if [[ ${WE_PAUSE_ON_FULLSCREEN:-1} == 1 ]]; then
        setsid "$DIR/we-fullscreen.sh" >/dev/null 2>&1 < /dev/null &
        echo $! > "$WE_STATE/we-watch.pid"
    fi
    [[ $quiet == --quiet ]] || notify -i "${WE_PREVIEW:-preferences-desktop-wallpaper}" "Live-Wallpaper" "${WE_TITLE:-$dir} (${WE_TYPE:-?})"
}

case "${1:-}" in
    ""|-h|--help) echo "Nutzung: $0 <Workshop-ID|Ordner> [--quiet] | restore | stop"; exit 0 ;;
    stop)    we_stop ;;
    restore) t=$(cat "$WE_STATE/we" 2>/dev/null) || exit 1; set_we "$t" --quiet ;;
    *)       set_we "$1" "${2:-}" ;;
esac

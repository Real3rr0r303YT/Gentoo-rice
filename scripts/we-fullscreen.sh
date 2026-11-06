#!/usr/bin/env bash
# Gentoo-rice – pausiert linux-wallpaperengine (SIGSTOP), solange der aktive Workspace ein Vollbildfenster hat
set -uo pipefail
# shellcheck source=scripts/we-lib.sh
source "$(dirname "$(readlink -f "$0")")/we-lib.sh"

SOCK="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/${HYPRLAND_INSTANCE_SIGNATURE:-}/.socket2.sock"
[[ -S $SOCK ]] || { echo "Hyprland-Socket nicht gefunden: $SOCK" >&2; exit 1; }
command -v socat >/dev/null || { echo "socat fehlt" >&2; exit 1; }

paused=0
check() {
    local fs=0 pid
    hyprctl activeworkspace -j 2>/dev/null | grep -qE '"hasfullscreen": *true' && fs=1
    if ((fs == 1 && paused == 0)); then
        for pid in $(we_pids); do kill -STOP "$pid" 2>/dev/null; done; paused=1
    elif ((fs == 0 && paused == 1)); then
        for pid in $(we_pids); do kill -CONT "$pid" 2>/dev/null; done; paused=0
    fi
}
resume() { local pid; for pid in $(we_pids); do kill -CONT "$pid" 2>/dev/null; done; }
trap 'resume; exit 0' TERM INT EXIT

check
socat -U - "UNIX-CONNECT:$SOCK" | while IFS= read -r ev; do
    case $ev in
        fullscreen\>\>*|workspace\>\>*|workspacev2\>\>*|focusedmon\>\>*|closewindow\>\>*|activewindowv2\>\>*) check ;;
    esac
done

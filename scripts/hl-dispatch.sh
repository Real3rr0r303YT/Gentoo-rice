#!/bin/sh
# Gentoo-rice – Hyprland-Dispatcher für alte (hyprlang) und neue (Lua) Versionen
# Nutzung: hl-dispatch.sh '<Lua-Ausdruck>' <alter Dispatcher> [Argumente…]
#   z. B.  hl-dispatch.sh 'hl.dsp.exit()' exit
lua=$1; shift
out=$(hyprctl dispatch "$lua" 2>&1)
[ "$out" = ok ] && exit 0
[ $# -gt 0 ] && exec hyprctl dispatch "$@"
echo "$out" >&2
exit 1

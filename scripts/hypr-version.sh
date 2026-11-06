#!/bin/sh
# Wählt die zur Hyprland-Version passenden Regeln (Syntax änderte sich in 0.53).
dir="$HOME/.config/hypr"
out="$dir/version.conf"
ver=$(Hyprland --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -n1)
major=${ver%%.*}; minor=${ver#*.}
if [ -z "$ver" ] || [ "$major" -gt 0 ] || [ "$minor" -ge 53 ]; then
    file=rules-new.conf
else
    file=rules-legacy.conf
fi
line="source = $dir/compat/$file"
[ "$(cat "$out" 2>/dev/null)" = "$line" ] && exit 0
printf '%s\n' "$line" > "$out"
[ -n "$HYPRLAND_INSTANCE_SIGNATURE" ] && hyprctl reload >/dev/null 2>&1
exit 0

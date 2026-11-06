#!/bin/sh
for p in /usr/libexec/hyprpolkitagent /usr/lib/hyprpolkitagent/hyprpolkitagent \
         /usr/libexec/polkit-gnome-authentication-agent-1 \
         /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1; do
    [ -x "$p" ] && exec "$p"
done
command -v hyprpolkitagent >/dev/null && exec hyprpolkitagent

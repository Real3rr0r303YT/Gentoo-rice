#!/bin/sh
choice=$(printf '%s\n' "Sperren" "Abmelden" "Ruhezustand" "Neu starten" "Ausschalten" |
    wofi --dmenu --prompt "System" --width 320 --height 280 --cache-file /dev/null)
case "$choice" in
    Sperren)      loginctl lock-session ;;
    Abmelden)     hyprctl dispatch exit ;;
    Ruhezustand)  loginctl suspend ;;
    "Neu starten") loginctl reboot ;;
    Ausschalten)  loginctl poweroff ;;
esac

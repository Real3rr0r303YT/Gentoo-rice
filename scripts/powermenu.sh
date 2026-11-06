#!/bin/sh
choice=$(printf '%s\n' "  Sperren" "  Abmelden" "  Ruhezustand" "  Neu starten" "  Ausschalten" |
    rofi -dmenu -i -p "" -theme "$HOME/.config/rofi/menu.rasi")
case "$choice" in
    *Sperren)      loginctl lock-session ;;
    *Abmelden)     hyprctl dispatch exit ;;
    *Ruhezustand)  loginctl suspend ;;
    *"Neu starten") loginctl reboot ;;
    *Ausschalten)  loginctl poweroff ;;
esac

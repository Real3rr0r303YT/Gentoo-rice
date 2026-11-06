#!/bin/sh
choice=$(printf '%s\n' "  Sperren" "  Abmelden" "  Ruhezustand" "  Neu starten" "  Ausschalten" |
    rofi -dmenu -i -p "" -theme "$HOME/.config/rofi/menu.rasi")
case "$choice" in
    *Sperren)      loginctl lock-session ;;
    *Abmelden)     "$(dirname "$(readlink -f "$0")")/hl-dispatch.sh" 'hl.dsp.exit()' exit ;;
    *Ruhezustand)  loginctl suspend ;;
    *"Neu starten") loginctl reboot ;;
    *Ausschalten)  loginctl poweroff ;;
esac

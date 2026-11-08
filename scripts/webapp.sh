#!/bin/sh
# Gentoo-rice – Web-App in einem eigenen Firefox-Fenster öffnen (Proton Mail/Calendar …)
url=${1:?URL fehlt}
if command -v firefox-bin >/dev/null; then exec firefox-bin --new-window "$url"
elif command -v firefox >/dev/null; then exec firefox --new-window "$url"
else exec xdg-open "$url"; fi

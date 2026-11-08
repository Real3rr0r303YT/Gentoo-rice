#!/usr/bin/env bash
# Gentoo-rice – Extra-Apps (Flatpak, ohne sudo):
#   Spotify + Spicetify (Theme in den Rice-Farben), Gaming (Minecraft Java, CurseForge, Sober),
#   OpSec (Proton VPN/Pass/Mail/Authenticator, Tor Browser, Signal), OBS Studio
# Copyright (C) 2026 3rr0r303YT – GPL-3.0-or-later
#
# Nutzung: ./scripts/apps.sh               alles installieren/aktualisieren
#          ./scripts/apps.sh spicetify     Spicetify neu anwenden (z. B. nach einem Spotify-Update)
#          ./scripts/apps.sh sync          nur Farben übernehmen (ruft wallpaper.sh/theme.sh auf)
set -Eeuo pipefail

REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
MODE=${1:-all}
case $MODE in all|spicetify|sync) ;; -h|--help) sed -n '2,9p' "$0"; exit 0 ;; *) echo "Unbekannt: $MODE" >&2; exit 1 ;; esac

SPOTIFY_ID=com.spotify.Client
# weitere Apps: "<Flatpak-ID[,Alternative]>|<Name>|<Hinweis>|<optional: 1 = fehlt auf Flathub ist ok>"
GAMING_APPS=(
    "com.mojang.Minecraft|Minecraft Java (offizieller Launcher)|Mit dem Microsoft-Konto anmelden, Java Edition starten|0"
    "com.overwolf.curseforge|CurseForge (Mods/Modpacks)|Minecraft-Modpacks installieren|1"
    "org.vinegarhq.Sober|Sober (Roblox)|Beim ersten Start mit dem Roblox-Konto anmelden|0"
)
OPSEC_APPS=(
    "com.protonvpn.www|Proton VPN|Anmelden → Schnellverbindung, Kill Switch in den Einstellungen|0"
    "me.proton.Pass|Proton Pass|Passwort-Manager|1"
    "me.proton.Mail|Proton Mail|Desktop-App|1"
    "me.proton.Authenticator|Proton Authenticator|2FA-Codes|1"
    "org.torproject.torbrowser-launcher,com.github.micahflee.torbrowser-launcher|Tor Browser|Erster Start lädt den Tor Browser herunter|0"
    "org.signal.Signal|Signal|Messenger mit Ende-zu-Ende-Verschlüsselung|0"
)
MEDIA_APPS=(
    "com.obsproject.Studio|OBS Studio|Bildschirm aufnehmen: Quelle 'Bildschirmaufnahme (PipeWire)'|0"
)
SPICE_HOME="$HOME/.spicetify"
SPICE_BIN="$HOME/.local/bin/spicetify"
SPICE_CFG="$HOME/.config/spicetify"
SPOTIFY_PATH="$HOME/.local/share/flatpak/app/$SPOTIFY_ID/x86_64/stable/active/files/extra/share/spotify"
SPOTIFY_PREFS="$HOME/.var/app/$SPOTIFY_ID/config/spotify/prefs"
export PATH="$HOME/.local/bin:$PATH"

# ── nur Farben (still, für wallpaper.sh) ──────────────────
if [[ $MODE == sync ]]; then
    if ! command -v spicetify >/dev/null || [[ ! -d $SPICE_CFG/Themes/GentooRice ]]; then exit 0; fi
    spicetify refresh -n -q </dev/null >/dev/null 2>&1 || true
    exit 0
fi

TOTAL=1 STEP_LABEL=apps
if [[ $MODE == all ]]; then TOTAL=5; fi
export GENTOO_RICE_SUDO_LOOP=1   # kein sudo nötig
# shellcheck source=scripts/lib.sh
source "$REPO/scripts/lib.sh"

flatpak_app() { # flatpak_app <id[,alternative…]> <name> [optional]
    local id ids
    IFS=',' read -ra ids <<<"$1"
    for id in "${ids[@]}"; do
        if flatpak info --user "$id" >/dev/null 2>&1; then ok "$2 vorhanden"; return 0; fi
    done
    for id in "${ids[@]}"; do
        if flatpak install --user -y --noninteractive flathub "$id" >>"$LOG" 2>&1; then ok "$2 installiert"; return 0; fi
    done
    if [[ ${3:-0} == 1 ]]; then info "$2 nicht auf Flathub verfügbar – übersprungen"; return 1; fi
    warn "$2 konnte nicht installiert werden (Details im Log)"; FAILED+=("${ids[0]} (Flatpak)"); return 1
}

app_list() { # app_list <eintrag…>
    local entry id name hint opt
    for entry in "$@"; do
        IFS='|' read -r id name hint opt <<<"$entry"
        if flatpak_app "$id" "$name" "$opt"; then info "$hint"; fi
    done
}

spicetify_cli() { # neueste Version von GitHub nach ~/.spicetify
    local tag ver url tmp
    tag=$(curl -fsSL https://api.github.com/repos/spicetify/cli/releases/latest | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n1) || true
    [[ -n $tag ]] || { warn "Spicetify-Version nicht ermittelbar (GitHub erreichbar?)"; return 1; }
    ver=${tag#v}
    if [[ -x $SPICE_HOME/spicetify && $("$SPICE_HOME/spicetify" -v 2>/dev/null) == "$ver" ]]; then
        ok "Spicetify $ver vorhanden"
    else
        url="https://github.com/spicetify/cli/releases/download/$tag/spicetify-$ver-linux-amd64.tar.gz"
        tmp=$(mktemp -d)
        if ! curl -fsSL "$url" -o "$tmp/s.tgz" || ! tar -xzf "$tmp/s.tgz" -C "$tmp"; then
            rm -rf "$tmp"; warn "Download fehlgeschlagen: $url"; return 1
        fi
        mkdir -p "$SPICE_HOME"
        cp -a "$tmp"/. "$SPICE_HOME"/; rm -f "$SPICE_HOME/s.tgz"; rm -rf "$tmp"
        chmod +x "$SPICE_HOME/spicetify"
        ok "Spicetify $ver installiert"
    fi
    mkdir -p "$(dirname "$SPICE_BIN")"
    ln -sfn "$SPICE_HOME/spicetify" "$SPICE_BIN"
}

spicetify_apply() {
    [[ -d $SPOTIFY_PATH ]] || { warn "Spotify (Flatpak) nicht gefunden: $SPOTIFY_PATH"; return 1; }
    command -v spicetify >/dev/null || { warn "spicetify fehlt"; return 1; }
    chmod -R u+w "$SPOTIFY_PATH" 2>/dev/null || true
    # prefs muss existieren (legt Spotify sonst erst beim ersten Start an)
    mkdir -p "$(dirname "$SPOTIFY_PREFS")"; [[ -f $SPOTIFY_PREFS ]] || : > "$SPOTIFY_PREFS"
    # Theme: user.css aus dem Repo, Farben aus ~/.cache/wal (wallpaper.sh/theme.sh)
    local t="$SPICE_CFG/Themes/GentooRice"
    mkdir -p "$t"
    ln -sfn "$REPO/spicetify/GentooRice/user.css" "$t/user.css"
    [[ -f $HOME/.cache/wal/spicetify-color.ini ]] || "$REPO/scripts/wallpaper.sh" colors >/dev/null 2>&1 || true
    if [[ -f $HOME/.cache/wal/spicetify-color.ini ]]; then ln -sfn "$HOME/.cache/wal/spicetify-color.ini" "$t/color.ini"
    else cp -n "$REPO/spicetify/GentooRice/color.ini" "$t/color.ini"; fi
    spicetify -c </dev/null >/dev/null 2>&1 || true   # legt config-xpui.ini an
    spicetify config spotify_path "$SPOTIFY_PATH/" prefs_path "$SPOTIFY_PREFS" \
        current_theme GentooRice color_scheme rice inject_css 1 replace_colors 1 </dev/null >>"$LOG" 2>&1 || true
    if spicetify apply -n </dev/null >>"$LOG" 2>&1 || spicetify backup apply -n </dev/null >>"$LOG" 2>&1 \
        || { spicetify restore </dev/null >>"$LOG" 2>&1; spicetify backup apply -n </dev/null >>"$LOG" 2>&1; }; then
        ok "Spicetify angewendet (Theme GentooRice, Farben vom Rice)"
    else
        warn "spicetify apply fehlgeschlagen – Details im Log"; FAILED+=("Spicetify (danach: ./scripts/apps.sh spicetify)"); return 1
    fi
}

printf '%s\n' "${B}Gentoo-rice${N} ${D}– Apps: Spotify + Spicetify, Gaming, OpSec (Proton), OBS Studio${N}"
command -v flatpak >/dev/null || die "flatpak fehlt (./install.sh richtet es ein)."
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo >>"$LOG" 2>&1 || true

if [[ $MODE == all ]]; then
    step "Spotify"
    flatpak_app "$SPOTIFY_ID" "Spotify" || true
    step "Gaming: Minecraft Java, CurseForge, Sober (Roblox)"
    app_list "${GAMING_APPS[@]}"
    step "OpSec: Proton VPN, Proton Pass, Proton Mail, Tor Browser, Signal"
    app_list "${OPSEC_APPS[@]}"
    step "OBS Studio"
    app_list "${MEDIA_APPS[@]}"
fi

step "Spicetify"
if flatpak info --user "$SPOTIFY_ID" >/dev/null 2>&1; then
    if spicetify_cli; then spicetify_apply || true; else FAILED+=("Spicetify-CLI"); fi
else
    warn "Spotify fehlt – Spicetify übersprungen"
fi

print_problems
printf '\n%sFertig.%s Spotify neu starten, damit Spicetify greift.\n' "$G$B" "$N"

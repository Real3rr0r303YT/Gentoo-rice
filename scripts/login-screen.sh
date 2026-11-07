#!/usr/bin/env bash
# Gentoo-rice – grafischer Login-Screen: SDDM (Wayland über Weston) + eigenes Theme
# Copyright (C) 2026 3rr0r303YT – GPL-3.0-or-later
#
# Nutzung: ./scripts/login-screen.sh [--theme gentoo-rice|minecraft]
#          ./install.sh --login            ./install.sh --login=minecraft
# Rückgängig: ./scripts/login-screen-uninstall.sh
# Notausgang, falls der Login-Screen nicht startet:
#   Strg+Alt+F2 → einloggen → sudo rc-update del display-manager default → sudo reboot
set -Eeuo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

THEME=gentoo-rice
while (($#)); do
    case $1 in
        --theme) THEME=${2:-}; shift ;;
        --theme=*) THEME=${1#*=} ;;
        -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
        *) printf 'Unbekannte Option: %s\n' "$1" >&2; exit 1 ;;
    esac
    shift
done
case $THEME in
    minecraft|blocks|gentoo-rice-blocks) THEME=gentoo-rice-blocks ;;
    ""|default|gentoo-rice) THEME=gentoo-rice ;;
    *) printf 'Unbekanntes Theme: %s (gentoo-rice | minecraft)\n' "$THEME" >&2; exit 1 ;;
esac

TOTAL=7 STEP_LABEL=login KW_FILE=/etc/portage/package.accept_keywords/gentoo-rice-login
# shellcheck source=scripts/links.sh
source "$REPO/scripts/links.sh"
# shellcheck source=scripts/lib.sh
source "$REPO/scripts/lib.sh"

USER_NAME=$(id -un)
STAMP=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_DIR=$LOGIN_STATE/backup/$STAMP
MANIFEST=$LOGIN_STATE/backup/manifest
SDDM_SHARE=$LOGIN_STATE/sddm
SESSION_WRAPPER=/usr/local/bin/gentoo-rice-session
SESSION_FILE=/usr/share/wayland-sessions/gentoo-rice.desktop

# ── Backup-Helfer ─────────────────────────────────────────
# Manifest-Zeilen: "M <backupdir> <pfad>" = verändert (Original gesichert)
#                  "N - <pfad>"           = neu angelegt (wird beim Deinstallieren gelöscht)
recorded() { [[ -f $MANIFEST ]] && awk -v p="$1" '$3 == p { f = 1 } END { exit !f }' "$MANIFEST"; }
record() { # record <pfad> – vor dem ersten Ändern sichern
    local f=$1
    recorded "$f" && return 0
    $SUDO mkdir -p "$(dirname "$MANIFEST")"
    if [[ -e $f || -L $f ]]; then
        $SUDO mkdir -p "$BACKUP_DIR$(dirname "$f")"
        $SUDO cp -a "$f" "$BACKUP_DIR$f"
        echo "M $BACKUP_DIR $f" | $SUDO tee -a "$MANIFEST" >/dev/null
        info "Backup: $f"
    else
        echo "N - $f" | $SUDO tee -a "$MANIFEST" >/dev/null
    fi
}
root_write() { # root_write <ziel> [modus] – Inhalt von stdin, mit Backup, nur bei Änderung
    local f=$1 mode=${2:-0644} tmp
    tmp=$(mktemp)
    cat > "$tmp"
    if [[ -f $f ]] && cmp -s "$tmp" "$f"; then rm -f "$tmp"; return 0; fi
    record "$f"
    $SUDO install -D -m "$mode" "$tmp" "$f"
    rm -f "$tmp"
    info "geschrieben: $f"
}

printf '%s\n' "${B}Gentoo-rice${N} ${D}– Login-Screen (SDDM, Theme: $THEME)${N}"

# ── 1. Pakete ─────────────────────────────────────────────
step "Pakete: SDDM, display-manager-init, Weston (Greeter-Compositor)"
as_dir package.use; as_dir package.accept_keywords
$SUDO touch "$KW_FILE"
write_root /etc/portage/package.use/gentoo-rice-login <<'EOF'
# Gentoo-rice – Login-Screen
gui-apps/sddm elogind
x11-misc/sddm elogind
dev-libs/weston kiosk drm
EOF
# SDDM liegt seit 2026 unter gui-apps/sddm (vorher x11-misc/sddm)
emerge_pkgs "gui-apps/sddm|x11-misc/sddm" gui-libs/display-manager-init
emerge_pkgs --optional dev-libs/weston dev-qt/qtwayland
{ installed gui-apps/sddm || installed x11-misc/sddm; } || die "SDDM (gui-apps/sddm) konnte nicht installiert werden – Details: $LOG"
installed gui-libs/display-manager-init || die "gui-libs/display-manager-init fehlt – Details: $LOG"
ok "SDDM installiert"

# ── 2. Hyprland-Sitzung ───────────────────────────────────
step "Hyprland-Sitzung"
if [[ -f /usr/share/wayland-sessions/hyprland.desktop ]]; then
    ok "vorhanden: /usr/share/wayland-sessions/hyprland.desktop"
else
    warn "/usr/share/wayland-sessions/hyprland.desktop fehlt – nutze eigene Sitzung"
fi
# Eigene Sitzung mit dbus-Sitzungsbus (OpenRC hat keinen systemd-User-Bus)
root_write "$SESSION_WRAPPER" 0755 <<'EOF'
#!/bin/sh
# Gentoo-rice – Hyprland-Sitzung für SDDM (OpenRC)
if command -v start-hyprland >/dev/null 2>&1; then H=start-hyprland; else H=Hyprland; fi
if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ] && command -v dbus-run-session >/dev/null 2>&1; then
    exec dbus-run-session "$H"
fi
exec "$H"
EOF
root_write "$SESSION_FILE" <<EOF
[Desktop Entry]
Name=Hyprland (Gentoo-rice)
Comment=Hyprland mit dem Gentoo-rice
Exec=$SESSION_WRAPPER
Type=Application
DesktopNames=Hyprland
EOF
ok "Sitzung 'Hyprland (Gentoo-rice)' ist Standard im Login-Screen"

# ── 3. Themes ─────────────────────────────────────────────
step "SDDM-Themes"
$SUDO install -d -m 0755 "$LOGIN_STATE"
$SUDO install -d -m 0755 -o "$USER_NAME" "$SDDM_SHARE"
$SUDO mkdir -p /usr/share/sddm/themes
for t in gentoo-rice gentoo-rice-blocks; do
    dst=/usr/share/sddm/themes/$t
    record "$dst"
    $SUDO rm -rf "$dst"
    $SUDO cp -r "$REPO/sddm/$t" "$dst"
    # Farben/Wallpaper/Avatar kommen aus $SDDM_SHARE (vom Benutzer aktualisierbar)
    $SUDO ln -sfn "$SDDM_SHARE/theme.conf.user" "$dst/theme.conf.user"
    ok "Theme $t → $dst"
done
# Mauszeiger systemweit, damit SDDM ihn findet
for cur in Bibata-Modern-Ice Bibata-Modern-Classic Bibata-Modern-Amber; do
    if [[ ! -d /usr/share/icons/$cur && -d $HOME/.local/share/icons/$cur ]]; then
        record "/usr/share/icons/$cur"
        $SUDO cp -r "$HOME/.local/share/icons/$cur" /usr/share/icons/
        info "Cursor $cur nach /usr/share/icons"
    fi
done

# ── 4. SDDM-Konfiguration ─────────────────────────────────
step "SDDM-Konfiguration (Wayland, deutsche Tastatur)"
if command -v weston >/dev/null; then
    root_write /etc/sddm/gentoo-rice-weston.ini <<'EOF'
# Gentoo-rice – Weston als Compositor für den SDDM-Greeter
[core]
idle-time=0

[keyboard]
keymap_layout=de
numlock-on=true

[libinput]
enable-tap=true
EOF
    root_write /etc/sddm.conf.d/10-gentoo-rice.conf <<EOF
# Gentoo-rice – von scripts/login-screen.sh erzeugt
[General]
DisplayServer=wayland
InputMethod=
Numlock=on

[Theme]
Current=$THEME
CursorTheme=Bibata-Modern-Ice
CursorSize=24

[Users]
RememberLastUser=true
RememberLastSession=true

[Wayland]
CompositorCommand=weston --shell=kiosk -c /etc/sddm/gentoo-rice-weston.ini
SessionDir=/usr/share/wayland-sessions
EOF
    ok "Wayland-Modus (Greeter läuft in Weston, Tastatur: de)"
else
    warn "Weston nicht verfügbar – SDDM läuft im X11-Modus"
    root_write /etc/X11/xorg.conf.d/00-gentoo-rice-keyboard.conf <<'EOF'
# Gentoo-rice – deutsches Tastaturlayout für den Login-Screen (X11)
Section "InputClass"
    Identifier "keyboard-de"
    MatchIsKeyboard "on"
    Option "XkbLayout" "de"
EndSection
EOF
    root_write /etc/sddm.conf.d/10-gentoo-rice.conf <<EOF
# Gentoo-rice – von scripts/login-screen.sh erzeugt (X11-Fallback, Weston fehlt)
[General]
DisplayServer=x11
InputMethod=
Numlock=on

[Theme]
Current=$THEME
CursorTheme=Bibata-Modern-Ice
CursorSize=24

[Users]
RememberLastUser=true
RememberLastSession=true

[Wayland]
SessionDir=/usr/share/wayland-sessions
EOF
    command -v Xorg >/dev/null || warn "Xorg fehlt ebenfalls – Login-Screen startet so nicht (x11-base/xorg-server oder dev-libs/weston installieren)"
fi

# ── 5. OpenRC ─────────────────────────────────────────────
step "OpenRC: display-manager"
DM_CONF=/etc/conf.d/display-manager
if [[ -f $DM_CONF ]] && grep -qE '^DISPLAYMANAGER="?sddm"?' "$DM_CONF"; then
    ok "DISPLAYMANAGER=\"sddm\" bereits gesetzt"
else
    record "$DM_CONF"
    if [[ -f $DM_CONF ]] && grep -qE '^DISPLAYMANAGER=' "$DM_CONF"; then
        $SUDO sed -i 's/^DISPLAYMANAGER=.*/DISPLAYMANAGER="sddm"/' "$DM_CONF"
    else
        echo 'DISPLAYMANAGER="sddm"' | $SUDO tee -a "$DM_CONF" >/dev/null
    fi
    ok "DISPLAYMANAGER=\"sddm\" in $DM_CONF"
fi
for svc in elogind:boot dbus:default display-manager:default; do
    s=${svc%%:*}; lvl=${svc#*:}
    [[ -x /etc/init.d/$s ]] || { warn "Dienst $s fehlt"; continue; }
    if rc-update show "$lvl" 2>/dev/null | grep -w "$s" >/dev/null; then
        info "$s ist in $lvl"
    elif $SUDO rc-update add "$s" "$lvl" >>"$LOG" 2>&1; then
        ok "rc-update add $s $lvl"
    else
        die "rc-update add $s $lvl fehlgeschlagen"
    fi
done

# ── 6. TTY1-Autostart entfernen ───────────────────────────
step "TTY1-Autostart entfernen (sonst startet Hyprland doppelt)"
for prof in "$HOME/.bash_profile" "$HOME/.zprofile"; do
    { [[ -f $prof ]] && grep -qF "$PROFILE_BEGIN" "$prof"; } || continue
    mkdir -p "$BACKUP_ROOT/login-$STAMP"
    cp -a "$prof" "$BACKUP_ROOT/login-$STAMP/"
    sed -i "/$PROFILE_BEGIN/,/$PROFILE_END/d" "$prof"
    ok "entfernt aus ${prof/#$HOME/\~} (Backup: ${BACKUP_ROOT/#$HOME/\~}/login-$STAMP)"
done
printf 'theme=%s\nuser=%s\ndate=%s\n' "$THEME" "$USER_NAME" "$STAMP" | $SUDO tee "$LOGIN_MARKER" >/dev/null

# ── 7. Wallpaper, Farben, Avatar übertragen ───────────────
step "Login-Screen an das Rice angleichen"
if "$REPO/scripts/sddm-sync.sh"; then
    ok "Wallpaper (unscharf), Palette und Avatar übertragen"
else
    warn "sddm-sync.sh fehlgeschlagen – Theme nutzt Standardfarben"
fi
[[ -s $HOME/.face ]] || info "Eigenes Profilbild: Bild als ~/.face speichern, dann scripts/sddm-sync.sh"

print_problems
printf '\n%s╭─ Login-Screen eingerichtet ───────────────────╮%s\n' "$B" "$N"
printf '  Theme: %s · Wayland: %s\n' "$THEME" "$(command -v weston >/dev/null && echo ja || echo 'nein (X11)')"
printf '  Wird beim nächsten Neustart aktiv:  %ssudo reboot%s\n' "$B" "$N"
printf '  %sNotausgang:%s Strg+Alt+F2 → einloggen →\n' "$Y$B" "$N"
printf '    sudo rc-update del display-manager default && sudo reboot\n'
printf '  Rückgängig: ./scripts/login-screen-uninstall.sh\n'
printf '%s╰───────────────────────────────────────────────╯%s\n' "$B" "$N"

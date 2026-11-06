#!/usr/bin/env bash
# Gentoo-rice – Installer
# Copyright (C) 2026 3rr0r303YT
# This program is free software: GNU GPL-3.0-or-later (siehe LICENSE)
set -Eeuo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/links.sh
source "$REPO/scripts/links.sh"

# ── Ausgabe ────────────────────────────────────────────────
if [[ -t 1 ]]; then
    B=$'\e[1m'; D=$'\e[2m'; R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; C=$'\e[36m'; N=$'\e[0m'
else
    B=; D=; R=; G=; Y=; C=; N=
fi
TOTAL=12; STEP=0; CURRENT="Start"
DONE=()
step() { STEP=$((STEP + 1)); CURRENT="$*"; printf '\n%s[%2d/%d]%s %s%s%s\n' "$C$B" "$STEP" "$TOTAL" "$N" "$B" "$*" "$N"; }
info() { printf '  %s•%s %s\n' "$D" "$N" "$*"; }
ok()   { printf '  %s✔%s %s\n' "$G" "$N" "$*"; }
warn() { printf '  %s!%s %s\n' "$Y" "$N" "$*"; }
die()  { printf '\n%s✘ Fehler:%s %s\n' "$R$B" "$N" "$*" >&2; exit 1; }
trap 'rc=$?; printf "\n%s✘ Abbruch in Schritt %d (%s), Befehl: %s (Exit %d)%s\n" "$R$B" "$STEP" "$CURRENT" "$BASH_COMMAND" "$rc" "$N" >&2; exit $rc' ERR

# ── Vorprüfung ─────────────────────────────────────────────
[[ -f /etc/gentoo-release ]] && command -v emerge >/dev/null || die "Dieses Skript läuft nur auf Gentoo Linux."
[[ $EUID -ne 0 ]] || die "Bitte als normaler Benutzer starten (nicht als root) – sudo wird bei Bedarf genutzt."
if command -v sudo >/dev/null; then SUDO=sudo
elif command -v doas >/dev/null; then SUDO=doas
else die "Weder sudo noch doas gefunden. Als root: emerge app-admin/sudo und Benutzer in /etc/sudoers eintragen."
fi
USER_NAME="$(id -un)"

printf '%s\n' "${B}Gentoo-rice${N} ${D}– Hyprland Setup für $USER_NAME${N}"
if [[ $SUDO == sudo ]]; then
    sudo -v || die "sudo-Authentifizierung fehlgeschlagen."
    ( while kill -0 $$ 2>/dev/null; do sudo -n true; sleep 50; done ) 2>/dev/null &
fi

EMERGE=(env CONFIG_PROTECT_MASK=/etc/portage emerge --noreplace --getbinpkg --binpkg-respect-use=y
        --autounmask=y --autounmask-continue=y --quiet-build=y --keep-going=n)
emerge_pkgs() { $SUDO "${EMERGE[@]}" "$@" || die "emerge fehlgeschlagen für: $*"; }

write_root() { # write_root <datei>  (Inhalt von stdin, nur bei Änderung)
    local f=$1 tmp; tmp=$(mktemp)
    cat > "$tmp"
    if ! $SUDO cmp -s "$tmp" "$f" 2>/dev/null; then
        $SUDO mkdir -p "$(dirname "$f")"
        $SUDO install -m 0644 "$tmp" "$f"
        info "geschrieben: $f"
    fi
    rm -f "$tmp"
}

as_dir() { # /etc/portage/package.* in Verzeichnisform sicherstellen
    local p=/etc/portage/$1
    if [[ -f $p ]]; then $SUDO mv "$p" "$p.tmp"; $SUDO mkdir -p "$p"; $SUDO mv "$p.tmp" "$p/00-original"; fi
    $SUDO mkdir -p "$p"
}

# ── 1. Grundwerkzeuge ──────────────────────────────────────
step "Grundwerkzeuge (git, eselect-repository)"
emerge_pkgs dev-vcs/git app-eselect/eselect-repository
ok "git + eselect-repository vorhanden"
DONE+=("Grundwerkzeuge")

# ── 2. GURU ────────────────────────────────────────────────
step "GURU-Overlay"
if ! eselect repository list -i 2>/dev/null | grep -w guru >/dev/null; then
    $SUDO eselect repository enable guru
    ok "GURU aktiviert"
else
    ok "GURU bereits aktiv"
fi
$SUDO emaint sync -r guru >/dev/null || die "Sync von GURU fehlgeschlagen."
ok "GURU synchronisiert"
DONE+=("GURU-Overlay aktiv + synchronisiert")

# ── 3. Portage-Konfiguration ───────────────────────────────
step "Portage: USE-Flags, Keywords, Lizenzen"
for d in package.use package.accept_keywords package.license; do as_dir "$d"; done

write_root /etc/portage/package.use/00-gentoo-rice-video <<'EOF'
# Radeon 780M (RDNA3)
*/* VIDEO_CARDS: -* amdgpu radeonsi
EOF
write_root /etc/portage/package.use/gentoo-rice <<'EOF'
# Gentoo-rice
media-libs/mesa vulkan vaapi
media-video/pipewire sound-server pipewire-alsa
gui-apps/waybar network pulseaudio tray
gui-wm/hyprland X
x11-terms/kitty wayland
media-gfx/imagemagick png jpeg
EOF
write_root /etc/portage/package.accept_keywords/gentoo-rice <<'EOF'
# Gentoo-rice – Hyprland-Ökosystem & GURU
gui-wm/hyprland ~amd64
gui-apps/hyprlock ~amd64
gui-apps/hypridle ~amd64
gui-apps/hyprpolkitagent ~amd64
gui-libs/aquamarine ~amd64
gui-libs/hyprutils ~amd64
gui-libs/hyprcursor ~amd64
gui-libs/hyprgraphics ~amd64
gui-libs/hyprland-qtutils ~amd64
gui-libs/hyprland-qt-support ~amd64
gui-libs/hyprtoolkit ~amd64
gui-libs/xdg-desktop-portal-hyprland ~amd64
dev-libs/hyprlang ~amd64
dev-libs/hyprland-protocols ~amd64
dev-util/hyprwayland-scanner ~amd64
dev-cpp/sdbus-c++ ~amd64
gui-apps/nwg-dock-hyprland ~amd64
games-util/mangohud ~amd64
games-util/gamemode ~amd64
EOF
write_root /etc/portage/package.license/gentoo-rice <<'EOF'
sys-kernel/linux-firmware linux-fw-redistributable
EOF

if ! grep -qE '^\s*de_DE\.UTF-8' /etc/locale.gen 2>/dev/null; then
    echo "de_DE.UTF-8 UTF-8" | $SUDO tee -a /etc/locale.gen >/dev/null
    $SUDO locale-gen >/dev/null
    info "Locale de_DE.UTF-8 erzeugt"
fi
ok "Portage konfiguriert"
DONE+=("USE-Flags/Keywords in /etc/portage/*/gentoo-rice")

# ── 4. Desktop-Pakete ──────────────────────────────────────
step "Hyprland & Desktop-Pakete"
PKGS_DESKTOP=(
    gui-wm/hyprland gui-apps/hyprlock gui-apps/hypridle
    gui-libs/xdg-desktop-portal-hyprland sys-apps/xdg-desktop-portal-gtk
    gui-apps/waybar gui-apps/wofi gui-apps/mako gui-apps/swaybg
    gui-apps/nwg-dock-hyprland x11-terms/kitty
    gui-apps/grim gui-apps/slurp gui-apps/wl-clipboard
    app-misc/brightnessctl x11-libs/libnotify x11-misc/xdg-user-dirs
    gnome-base/dconf media-gfx/imagemagick dev-lang/sassc
    sys-auth/elogind sys-apps/dbus sys-auth/polkit
)
PKGS_OPTIONAL=( gui-apps/hyprpolkitagent media-sound/pavucontrol xfce-base/thunar net-misc/networkmanager )
emerge_pkgs "${PKGS_DESKTOP[@]}"
for p in "${PKGS_OPTIONAL[@]}"; do
    $SUDO "${EMERGE[@]}" "$p" >/dev/null 2>&1 && ok "$p" || warn "optional übersprungen: $p"
done
ok "Desktop-Pakete installiert"
DONE+=("Hyprland, hyprlock, hypridle, Waybar, Wofi, Mako, Dock, Kitty")

# ── 5. Fonts ───────────────────────────────────────────────
step "Fonts (Inter, JetBrains Mono, Font Awesome)"
emerge_pkgs media-fonts/inter media-fonts/jetbrains-mono media-fonts/fontawesome media-fonts/noto-emoji
fc-cache -f >/dev/null 2>&1 || true
ok "Fonts installiert"
DONE+=("Fonts Inter + JetBrains Mono")

# ── 6. Themes ──────────────────────────────────────────────
step "WhiteSur GTK-, Icon- und Cursor-Theme"
SRC="$HOME/.cache/gentoo-rice/src"; mkdir -p "$SRC"
fetch() { # fetch <repo>
    if [[ -d $SRC/$1/.git ]]; then git -C "$SRC/$1" pull -q --ff-only || warn "Update von $1 fehlgeschlagen, nutze vorhandene Version"
    else git clone -q --depth=1 "https://github.com/vinceliuice/$1.git" "$SRC/$1"; fi
}
if [[ ! -d $HOME/.themes/WhiteSur-Dark ]]; then
    fetch WhiteSur-gtk-theme
    (cd "$SRC/WhiteSur-gtk-theme" && ./install.sh -c dark -d "$HOME/.themes" >/dev/null) || die "WhiteSur-GTK-Installation fehlgeschlagen."
fi
ok "GTK: WhiteSur-Dark"
if [[ ! -d $HOME/.local/share/icons/WhiteSur-dark ]]; then
    fetch WhiteSur-icon-theme
    (cd "$SRC/WhiteSur-icon-theme" && ./install.sh -d "$HOME/.local/share/icons" >/dev/null) || die "WhiteSur-Icon-Installation fehlgeschlagen."
fi
ok "Icons: WhiteSur-dark"
if [[ ! -d $HOME/.local/share/icons/WhiteSur-cursors ]]; then
    fetch WhiteSur-cursors
    mkdir -p "$HOME/.local/share/icons"
    cp -r "$SRC/WhiteSur-cursors/dist" "$HOME/.local/share/icons/WhiteSur-cursors"
fi
mkdir -p "$HOME/.icons/default"
printf '[Icon Theme]\nInherits=WhiteSur-cursors\n' > "$HOME/.icons/default/index.theme"
ok "Cursor: WhiteSur-cursors"
DONE+=("Themes WhiteSur (GTK/Icons/Cursor)")

# ── 7. Configs verlinken ───────────────────────────────────
step "Configs sichern & verlinken"
STAMP=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP="$BACKUP_ROOT/$STAMP"
backed=0
for entry in "${LINKS[@]}"; do
    src="$REPO/${entry%%|*}"; src="${src%/.}"
    dst="$HOME/${entry#*|}"
    if [[ -L $dst && "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]]; then
        info "ok: ~/${entry#*|}"; continue
    fi
    if [[ -e $dst || -L $dst ]]; then
        mkdir -p "$BACKUP/$(dirname "${entry#*|}")"
        mv "$dst" "$BACKUP/${entry#*|}"
        backed=1; info "gesichert: ~/${entry#*|}"
    fi
    mkdir -p "$(dirname "$dst")"
    ln -s "$src" "$dst"
    ok "verlinkt: ~/${entry#*|}"
done
[[ $backed -eq 1 ]] && DONE+=("Backup: $BACKUP") || true
"$REPO/scripts/hypr-version.sh"
PINNED="$HOME/.cache/nwg-dock-pinned"
[[ -s $PINNED ]] || printf '%s\n' kitty thunar com.valvesoftware.Steam > "$PINNED"
xdg-user-dirs-update >/dev/null 2>&1 || true
gsettings set org.gnome.desktop.interface gtk-theme 'WhiteSur-Dark'         2>/dev/null || true
gsettings set org.gnome.desktop.interface icon-theme 'WhiteSur-dark'        2>/dev/null || true
gsettings set org.gnome.desktop.interface cursor-theme 'WhiteSur-cursors'   2>/dev/null || true
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'        2>/dev/null || true
gsettings set org.gnome.desktop.interface font-name 'Inter 11'              2>/dev/null || true
gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrains Mono 11' 2>/dev/null || true
DONE+=("Configs verlinkt nach ~/.config")

# ── 8. Audio ───────────────────────────────────────────────
step "PipeWire + WirePlumber"
emerge_pkgs media-video/pipewire media-video/wireplumber
for g in audio video input pipewire seat gamemode; do
    if getent group "$g" >/dev/null && ! id -nG "$USER_NAME" | grep -w "$g" >/dev/null; then
        $SUDO usermod -aG "$g" "$USER_NAME"; info "Gruppe $g hinzugefügt"
    fi
done
for svc in elogind:boot dbus:default; do
    s=${svc%%:*}; lvl=${svc#*:}
    rc-update show "$lvl" 2>/dev/null | grep -w "$s" >/dev/null || { $SUDO rc-update add "$s" "$lvl" >/dev/null; info "rc-update add $s $lvl"; }
done
ok "PipeWire startet mit Hyprland (gentoo-pipewire-launcher)"
DONE+=("PipeWire/WirePlumber")

# ── 9. Autostart ───────────────────────────────────────────
step "Hyprland-Autostart auf TTY1"
SNIPPET="$PROFILE_BEGIN
if [ -z \"\${WAYLAND_DISPLAY:-}\" ] && [ \"\$(tty)\" = \"/dev/tty1\" ]; then
    if command -v start-hyprland >/dev/null 2>&1; then exec dbus-run-session start-hyprland
    else exec dbus-run-session Hyprland; fi
fi
$PROFILE_END"
for prof in "$HOME/.bash_profile" "$HOME/.zprofile"; do
    [[ $prof == *zprofile && ! -f $prof ]] && continue
    touch "$prof"
    if grep -qF "$PROFILE_BEGIN" "$prof"; then
        sed -i "/$PROFILE_BEGIN/,/$PROFILE_END/d" "$prof"
    fi
    printf '\n%s\n' "$SNIPPET" >> "$prof"
    ok "Autostart in ${prof/#$HOME/\~}"
done
DONE+=("Autostart Hyprland auf TTY1")

# ── 10. Grafik ─────────────────────────────────────────────
step "Mesa / Vulkan für Radeon 780M"
emerge_pkgs sys-kernel/linux-firmware
$SUDO "${EMERGE[@]/--noreplace/--update}" --newuse --deep \
    media-libs/mesa media-libs/vulkan-loader x11-libs/libdrm media-libs/libva \
    || die "Mesa/Vulkan-Update fehlgeschlagen."
emerge_pkgs dev-util/vulkan-tools x11-apps/mesa-progs
ok "Mesa (radeonsi + RADV) installiert"
DONE+=("Mesa/Vulkan (RADV) für Radeon 780M")

# ── 11. Gaming ─────────────────────────────────────────────
step "Gaming: gamemode, mangohud, Flatpak, Steam"
emerge_pkgs games-util/gamemode games-util/mangohud sys-apps/flatpak
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
ok "Flathub (user) eingerichtet"
flatpak install --user -y --noninteractive flathub com.valvesoftware.Steam
RT=$(flatpak info --user com.valvesoftware.Steam 2>/dev/null | awk -F/ '/Runtime:/{print $NF}')
if [[ -n $RT ]]; then
    flatpak install --user -y --noninteractive flathub "org.freedesktop.Platform.VulkanLayer.MangoHud//$RT" \
        && ok "MangoHud-Layer für Steam ($RT)" || warn "MangoHud-Flatpak-Layer nicht installiert"
fi
flatpak override --user --filesystem=xdg-config/MangoHud:ro com.valvesoftware.Steam
ok "Steam installiert"
DONE+=("gamemode, mangohud, Flatpak + Flathub, Steam")

# ── 12. Fertig ─────────────────────────────────────────────
step "Abschluss"
fc-cache -f >/dev/null 2>&1 || true
ok "Alles erledigt"

printf '\n%s╭─ Zusammenfassung ─────────────────────────────╮%s\n' "$B" "$N"
for d in "${DONE[@]}"; do printf '  %s✔%s %s\n' "$G" "$N" "$d"; done
printf '%s╰───────────────────────────────────────────────╯%s\n' "$B" "$N"
printf '\n%sJetzt neu starten:%s %s\n' "$B$Y" "$N" "loginctl reboot"
printf '%sNach dem Login auf TTY1 startet Hyprland automatisch.%s\n' "$D" "$N"
printf '%sSteam in Spielen: Startoptionen  →  gamemoderun mangohud %%command%%%s\n\n' "$D" "$N"
if [[ -t 0 ]]; then
    read -r -p "Jetzt neu starten? [j/N] " a
    [[ $a =~ ^[jJyY]$ ]] && { loginctl reboot 2>/dev/null || $SUDO reboot; }
fi
exit 0

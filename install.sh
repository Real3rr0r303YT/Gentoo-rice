#!/usr/bin/env bash
# Gentoo-rice – Installer
# Copyright (C) 2026 3rr0r303YT
# This program is free software: GNU GPL-3.0-or-later (siehe LICENSE)
set -Eeuo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/links.sh
source "$REPO/scripts/links.sh"

DEV=0 WE=0
for arg in "$@"; do
    case $arg in
        --dev) DEV=1 ;;
        --we)  WE=1 ;;
        -h|--help) printf 'Nutzung: ./install.sh [--dev] [--we]\n  --dev  zusätzlich Entwickler-Setup (scripts/dev-setup.sh)\n  --we   zusätzlich Wallpaper Engine (scripts/wallpaperengine.sh)\n'; exit 0 ;;
        *) printf 'Unbekannte Option: %s (siehe --help)\n' "$arg" >&2; exit 1 ;;
    esac
done

# ── Ausgabe ────────────────────────────────────────────────
if [[ -t 1 ]]; then
    B=$'\e[1m'; D=$'\e[2m'; R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; C=$'\e[36m'; N=$'\e[0m'
else
    B=; D=; R=; G=; Y=; C=; N=
fi
TOTAL=$((14 + DEV + WE)); STEP=0; CURRENT="Start"
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
SKIPPED=()

# ── Paket-/Repo-Helfer ─────────────────────────────────────
pkg_check() { # 0 = installierbar/installiert, 1 = in keinem Repo verfügbar
    local out
    portageq has_version / "$1" 2>/dev/null && return 0
    [[ -n $(pkg_repos "$1") ]] || return 1
    # nur ~amd64 vorhanden → Keyword freigeben
    if [[ -z $(portageq best_visible / ebuild "$1" 2>/dev/null) ]]; then
        $SUDO mkdir -p /etc/portage/package.accept_keywords
        $SUDO touch /etc/portage/package.accept_keywords/gentoo-rice-auto
        $SUDO grep -qxF "$1 ~amd64" /etc/portage/package.accept_keywords/gentoo-rice-auto ||
            echo "$1 ~amd64" | $SUDO tee -a /etc/portage/package.accept_keywords/gentoo-rice-auto >/dev/null
    fi
    out=$($SUDO emerge -p --quiet --autounmask=y --autounmask-continue=n "$1" 2>&1) && return 0
    if grep -qE 'there are no ebuilds (to satisfy|built with USE)|have been masked|is not a valid package atom|is ambiguous' <<<"$out"; then
        return 1
    fi
    return 0 # andere Probleme (Keywords/USE) löst autounmask beim echten emerge
}

emerge_pkgs() { # emerge_pkgs "<atom>[|alternative…]" …  – nicht verfügbare Pakete werden gemeldet und übersprungen
    local spec a p todo=()
    for spec in "$@"; do
        p=""
        for a in ${spec//|/ }; do
            if portageq has_version / "$a" 2>/dev/null || [[ -n $(pkg_repos "$a") ]]; then p=$a; break; fi
        done
        if [[ -n $p ]] && pkg_check "$p"; then todo+=("$p")
        else warn "nicht verfügbar, übersprungen: ${spec//|/ oder }"; SKIPPED+=("${spec%%|*}"); fi
    done
    ((${#todo[@]})) || return 0
    $SUDO "${EMERGE[@]}" "${todo[@]}" || die "emerge fehlgeschlagen für: ${todo[*]}"
}

repo_path() { local p; p=$(portageq get_repo_path / "$1" 2>/dev/null) || true; echo "${p:-/var/db/repos/$1}"; }
repo_enabled() { eselect repository list -i 2>/dev/null | grep -w -- "$1" >/dev/null; }
repo_synced() { local p; p=$(repo_path "$1"); [[ -d $p && -d $p/metadata && -n "$(ls -A "$p" 2>/dev/null)" ]]; }

ensure_repo() { # aktivieren + syncen, falls nötig
    if ! repo_enabled "$1"; then
        $SUDO eselect repository enable "$1" >/dev/null || return 1
        info "$1 aktiviert"
    fi
    if ! repo_synced "$1"; then
        info "synchronisiere $1 …"
        $SUDO emaint sync -r "$1" >/dev/null || return 1
    fi
    repo_synced "$1"
}

pkg_repos() { # Repos, die Ebuilds für <cat/pkg> enthalten
    local r out=()
    for r in $(portageq get_repos / 2>/dev/null); do
        compgen -G "$(repo_path "$r")/$1/*.ebuild" >/dev/null && out+=("$r")
    done
    echo "${out[*]}"
}

hypr_keywords() { # Keywords für alle hypr*-Pakete aller Repos (sortiert)
    local r p d cp e
    local -A kw=() from=()
    for r in $(portageq get_repos / 2>/dev/null); do
        p=$(repo_path "$r"); [[ -d $p ]] || continue
        for d in "$p"/*/hypr* "$p"/*/aquamarine "$p"/*/xdg-desktop-portal-hyprland "$p"/*/nwg-dock-hyprland; do
            [[ -d $d ]] && compgen -G "$d/*.ebuild" >/dev/null || continue
            cp=${d#"$p"/}
            from[$cp]="${from[$cp]:+${from[$cp]},}$r"
            [[ ${kw[$cp]:-} == "~amd64" ]] || kw[$cp]="**"
            for e in "$d"/*.ebuild; do [[ $e == *-9999.ebuild ]] || { kw[$cp]="~amd64"; break; }; done
        done
    done
    for cp in "${!kw[@]}"; do printf '%-42s %-7s # %s\n' "$cp" "${kw[$cp]}" "${from[$cp]}"; done | sort
}


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
command -v eselect >/dev/null && command -v git >/dev/null || die "git/eselect-repository konnten nicht installiert werden."
ok "git + eselect-repository vorhanden"
DONE+=("Grundwerkzeuge")

# ── 2. Repositories ────────────────────────────────────────
step "Repositories: GURU & Hyprland-Quelle"
ensure_repo guru || die "GURU konnte nicht aktiviert/synchronisiert werden (eselect repository enable guru && emaint sync -r guru)."
ok "GURU aktiv + synchronisiert ($(repo_path guru))"

if [[ -z $(pkg_repos gui-wm/hyprland) ]]; then
    warn "gui-wm/hyprland nicht gefunden – synchronisiere Gentoo-Hauptrepo"
    $SUDO emaint sync -r gentoo >/dev/null || warn "Sync von ::gentoo fehlgeschlagen"
fi
if [[ -z $(pkg_repos gui-wm/hyprland) ]]; then
    warn "gui-wm/hyprland weiterhin nicht gefunden – aktiviere hyproverlay"
    ensure_repo hyproverlay && ok "hyproverlay aktiv + synchronisiert" || warn "hyproverlay konnte nicht eingerichtet werden"
fi
HYPR_REPOS=$(pkg_repos gui-wm/hyprland)
[[ -n $HYPR_REPOS ]] || die "gui-wm/hyprland ist in keinem Repository verfügbar.
   Aktive Repos: $(portageq get_repos / 2>/dev/null | tr '\n' ' ')
   Prüfen: emaint sync -a  ·  eselect repository list -i  ·  ls /var/db/repos/gentoo/gui-wm/
   Danach ./install.sh erneut starten."
for p in gui-wm/hyprland gui-apps/hyprlock gui-apps/hypridle gui-libs/xdg-desktop-portal-hyprland gui-apps/hyprpaper; do
    r=$(pkg_repos "$p")
    if [[ -n $r ]]; then info "$p ← ${r// /, }"; else warn "$p in keinem Repo"; fi
done
ok "Hyprland verfügbar aus: ${HYPR_REPOS// /, }"
DONE+=("Repos: GURU + Hyprland aus ${HYPR_REPOS// /, }")

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
x11-misc/rofi wayland
media-sound/cava pulseaudio pipewire
media-video/mpv libmpv
media-video/ffmpeg x264 vpx
EOF
{
    echo "# Gentoo-rice – automatisch erzeugt von install.sh"
    echo "# Hyprland-Ökosystem (Repo-Herkunft als Kommentar)"
    hypr_keywords
    echo "# Abhängigkeiten / Gaming"
    printf '%-42s %s\n' dev-cpp/sdbus-c++ "~amd64" dev-cpp/glaze "~amd64" \
        games-util/mangohud "~amd64" games-util/gamemode "~amd64"
} | write_root /etc/portage/package.accept_keywords/gentoo-rice
info "$(grep -c '^[a-z]' /etc/portage/package.accept_keywords/gentoo-rice) Keyword-Einträge"
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
pkg_check gui-wm/hyprland || die "gui-wm/hyprland ist nicht installierbar (emerge -p gui-wm/hyprland zeigt den Grund)."
PKGS_DESKTOP=(
    gui-wm/hyprland gui-apps/hyprlock gui-apps/hypridle
    gui-libs/xdg-desktop-portal-hyprland sys-apps/xdg-desktop-portal-gtk
    gui-apps/waybar x11-misc/rofi gui-apps/mako x11-terms/kitty x11-misc/xdg-utils
    "gui-apps/awww|gui-apps/swww" gui-apps/mpvpaper media-video/mpv media-video/ffmpeg
    media-sound/playerctl gui-apps/grim gui-apps/slurp gui-apps/wl-clipboard
    app-misc/brightnessctl x11-libs/libnotify x11-misc/xdg-user-dirs
    gnome-base/dconf media-gfx/imagemagick dev-python/pipx
    sys-auth/elogind sys-apps/dbus sys-auth/polkit
)
PKGS_TOYS=(
    app-misc/fastfetch media-sound/cava sys-process/btop
    "app-misc/cmatrix|games-misc/cmatrix|x11-misc/cmatrix"
    "app-misc/tty-clock|x11-misc/tty-clock|games-misc/tty-clock"
)
PKGS_OPTIONAL=( gui-apps/hyprpolkitagent media-sound/pavucontrol xfce-base/thunar net-misc/networkmanager
                net-wireless/bluez net-wireless/blueman x11-themes/papirus-icon-theme )
emerge_pkgs "${PKGS_DESKTOP[@]}"
emerge_pkgs "${PKGS_TOYS[@]}"
for p in "${PKGS_OPTIONAL[@]}"; do
    if ! pkg_check "$p"; then warn "optional, nicht verfügbar: $p"; SKIPPED+=("$p"); continue; fi
    $SUDO "${EMERGE[@]}" "$p" >/dev/null 2>&1 && ok "$p" || { warn "optional fehlgeschlagen: $p"; SKIPPED+=("$p"); }
done
portageq has_version / gui-wm/hyprland || die "Hyprland wurde nicht installiert."
ok "Desktop-Pakete installiert"
DONE+=("Hyprland, hyprlock, hypridle, Waybar, rofi, mako, kitty, swww, mpvpaper, cava, btop, cmatrix, tty-clock")

# ── 5. Fonts ───────────────────────────────────────────────
step "Fonts (JetBrains Mono, Font Awesome, Noto CJK/Emoji)"
emerge_pkgs media-fonts/jetbrains-mono media-fonts/fontawesome media-fonts/noto-emoji media-fonts/noto-cjk
fc-cache -f >/dev/null 2>&1 || true
ok "Fonts installiert"
DONE+=("Fonts JetBrains Mono, Font Awesome, Noto CJK")

# ── 6. Themes ──────────────────────────────────────────────
step "Themes: Adwaita-dark, Papirus-Dark, Bibata-Cursor"
if [[ -d /usr/share/icons/Papirus-Dark || -d $HOME/.local/share/icons/Papirus-Dark ]]; then ok "Icons: Papirus-Dark"
else warn "Papirus-Dark nicht installiert (x11-themes/papirus-icon-theme)"; fi
if [[ ! -d $HOME/.local/share/icons/Bibata-Modern-Classic ]]; then
    tmp=$(mktemp -d)
    if curl -fsSL -o "$tmp/b.tar.xz" https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/Bibata-Modern-Classic.tar.xz \
        && mkdir -p "$HOME/.local/share/icons" && tar -xJf "$tmp/b.tar.xz" -C "$HOME/.local/share/icons"; then
        ok "Cursor: Bibata-Modern-Classic"
    else
        warn "Bibata-Cursor konnte nicht geladen werden – Standard-Cursor bleibt"; SKIPPED+=("Bibata-Cursor")
    fi
    rm -rf "$tmp"
else
    ok "Cursor: Bibata-Modern-Classic"
fi
mkdir -p "$HOME/.icons/default"
printf '[Icon Theme]\nInherits=Bibata-Modern-Classic\n' > "$HOME/.icons/default/index.theme"
DONE+=("Themes: Adwaita-dark, Papirus-Dark, Bibata")

# ── 7. Configs verlinken ───────────────────────────────────
step "Configs sichern & verlinken"
STAMP=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP="$BACKUP_ROOT/$STAMP"
backed=0
link_one() { # link_one <quelle> <ziel relativ zu $HOME>  – sichert Vorhandenes, dann Symlink
    local src=$1 rel=$2 dst="$HOME/$2"
    if [[ -L $dst && "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]]; then
        info "ok: ~/$rel"; return 0
    fi
    if [[ -e $dst || -L $dst ]]; then
        mkdir -p "$BACKUP/$(dirname "$rel")"
        mv "$dst" "$BACKUP/$rel"
        backed=1; info "gesichert: ~/$rel"
    fi
    mkdir -p "$(dirname "$dst")"
    ln -s "$src" "$dst"
    ok "verlinkt: ~/$rel"
}
# Aufräumen: Links früherer Rice-Versionen (wofi, mako, Dock)
for rel in "${LEGACY_LINKS[@]}"; do
    if [[ -L $HOME/$rel && "$(readlink "$HOME/$rel")" == "$REPO"/* ]]; then rm "$HOME/$rel"; info "alt entfernt: ~/$rel"; fi
done
for entry in "${LINKS[@]}"; do
    src="$REPO/${entry%%|*}"; src="${src%/.}"
    link_one "$src" "${entry#*|}"
done
# Links im Repo auf die generierten Farben (gitignored)
for entry in "${GENERATED_LINKS[@]}"; do
    ln -sfn "$HOME/${entry#*|}" "$REPO/${entry%%|*}"
done
[[ $backed -eq 1 ]] && DONE+=("Backup: $BACKUP") || true
"$REPO/scripts/hypr-version.sh"
xdg-user-dirs-update >/dev/null 2>&1 || true
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'          2>/dev/null || true
gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'         2>/dev/null || true
gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Classic' 2>/dev/null || true
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'        2>/dev/null || true
gsettings set org.gnome.desktop.interface font-name 'JetBrains Mono 10'     2>/dev/null || true
gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrains Mono 11' 2>/dev/null || true
DONE+=("Configs verlinkt nach ~/.config")

# ── 8. Wallpaper & Farben ──────────────────────────────────
step "Wallpaper & dynamische Farben (pywal16)"
export PATH="$HOME/.local/bin:$PATH"
if command -v wal >/dev/null; then
    ok "pywal16 vorhanden"
elif command -v pipx >/dev/null && pipx install pywal16 >/dev/null 2>&1; then
    ok "pywal16 installiert (pipx)"
else
    warn "pywal16 nicht installierbar – festes Fallback-Farbschema wird genutzt"; SKIPPED+=("pywal16")
fi
mkdir -p "$WALLPAPER_DIR"
for f in "$REPO"/wallpapers/*.jpg; do
    [[ -e $WALLPAPER_DIR/$(basename "$f") ]] || { cp "$f" "$WALLPAPER_DIR/"; info "Wallpaper: $(basename "$f")"; }
done
"$REPO/scripts/wallpaper.sh" init || die "Farbschema konnte nicht erzeugt werden."
[[ -f $HOME/.cache/wal/colors-hyprland.conf ]] || die "~/.cache/wal/colors-hyprland.conf fehlt."
ok "Farbschema aus $(basename "$(cat "$HOME/.cache/rice/wallpaper")")"

# btop: Terminal-Farben (folgen pywal)
BTOP="$HOME/.config/btop/btop.conf"; mkdir -p "$(dirname "$BTOP")"
if [[ -f $BTOP ]]; then
    sed -i -e 's/^color_theme *=.*/color_theme = "TTY"/' -e 's/^theme_background *=.*/theme_background = False/' "$BTOP"
    grep -q '^color_theme' "$BTOP" || echo 'color_theme = "TTY"' >> "$BTOP"
else
    printf 'color_theme = "TTY"\ntheme_background = False\nrounded_corners = True\n' > "$BTOP"
fi
ok "btop: TTY-Theme (pywal-Farben)"

# Songtext-Overlay (optional): sptlrx aus GitHub-Release
if command -v sptlrx >/dev/null; then
    ok "sptlrx vorhanden"
else
    url=$(curl -fsSL https://api.github.com/repos/raitonoberu/sptlrx/releases/latest 2>/dev/null |
        grep -oE '"browser_download_url": *"[^"]+linux_(amd64|x86_64)[^"]*\.tar\.gz"' | head -n1 | grep -oE 'https[^"]+' || true)
    tmp=$(mktemp -d)
    if [[ -n $url ]] && curl -fsSL "$url" | tar -xz -C "$tmp" && [[ -f $tmp/sptlrx ]]; then
        install -Dm755 "$tmp/sptlrx" "$HOME/.local/bin/sptlrx"; ok "sptlrx installiert (Songtexte, Super+Y)"
    else
        warn "sptlrx nicht installiert (optional)"; SKIPPED+=("sptlrx")
    fi
    rm -rf "$tmp"
fi
DONE+=("Wallpaper in ~/Pictures/wallpapers, Farben via pywal16")

# ── 8. Firefox ─────────────────────────────────────────────
step "Firefox (Binärversion)"
emerge_pkgs www-client/firefox-bin x11-misc/xdg-utils
FF_BIN=$(command -v firefox-bin || command -v firefox || true)
[[ -n $FF_BIN ]] || die "Firefox nicht installiert (www-client/firefox-bin)."
ok "Firefox: $FF_BIN"

# Policies: Telemetrie aus, Tracking-Schutz streng, uBlock Origin
FF_POLICY_DIRS=(/etc/firefox/policies)
[[ -d /opt/firefox ]] && FF_POLICY_DIRS+=(/opt/firefox/distribution)
for d in "${FF_POLICY_DIRS[@]}"; do write_root "$d/policies.json" < "$REPO/firefox/policies.json"; done
ok "policies.json (${FF_POLICY_DIRS[*]})"

# Standardbrowser
FF_DESKTOP=firefox-bin.desktop
[[ -f /usr/share/applications/$FF_DESKTOP ]] || FF_DESKTOP=firefox.desktop
xdg-mime default "$FF_DESKTOP" x-scheme-handler/http x-scheme-handler/https text/html application/xhtml+xml \
    || warn "xdg-mime fehlgeschlagen"
XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-Hyprland} xdg-settings set default-web-browser "$FF_DESKTOP" 2>/dev/null || true
ok "Standardbrowser: $FF_DESKTOP"

# Profil finden bzw. einmalig headless anlegen lassen
ff_profile() {
    local base ini p
    for base in "$HOME/.config/mozilla/firefox" "$HOME/.mozilla/firefox"; do
        ini="$base/profiles.ini"; [[ -f $ini ]] || continue
        p=$(awk -F= '/^\[Install/{s=1;next} /^\[/{s=0} s && $1=="Default"{print $2; exit}' "$ini")
        [[ -n $p ]] || p=$(awk -F= '/^\[/{path="";def=0} $1=="Path"{path=$2} $1=="Default"&&$2=="1"{def=1} def&&path!=""{print path; exit}' "$ini")
        [[ -n $p ]] || continue
        [[ $p == /* ]] || p="$base/$p"
        [[ -d $p ]] && { echo "$p"; return 0; }
    done
    return 1
}
if ! FF_PROFILE=$(ff_profile); then
    info "lege Firefox-Profil an (headless) …"
    timeout 20 "$FF_BIN" --headless --no-remote about:blank >/dev/null 2>&1 || true
    sleep 1
fi
if FF_PROFILE=$(ff_profile); then
    FF_REL=${FF_PROFILE#"$HOME"/}
    link_one "$REPO/firefox/user.js" "$FF_REL/user.js"
    link_one "$REPO/firefox/userChrome.css" "$FF_REL/chrome/userChrome.css"
    mkdir -p "$(dirname "$EXTRA_LINKS_FILE")"; touch "$EXTRA_LINKS_FILE"
    for rel in "$FF_REL/user.js" "$FF_REL/chrome/userChrome.css"; do
        grep -qxF "$rel" "$EXTRA_LINKS_FILE" || echo "$rel" >> "$EXTRA_LINKS_FILE"
    done
    ok "Rice-Look im Profil ${FF_PROFILE/#$HOME/\~}"
else
    warn "Kein Firefox-Profil gefunden – Firefox einmal starten und ./install.sh erneut ausführen"
fi
[[ $backed -eq 1 && ! " ${DONE[*]} " == *"Backup: $BACKUP"* ]] && DONE+=("Backup: $BACKUP") || true
DONE+=("Firefox (Standardbrowser, Policies, uBlock Origin, userChrome.css)")

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
touch "$HOME/.bashrc"
grep -qF "$FASTFETCH_BEGIN" "$HOME/.bashrc" && sed -i "/$FASTFETCH_BEGIN/,/$FASTFETCH_END/d" "$HOME/.bashrc"
cat >> "$HOME/.bashrc" <<EOF
$FASTFETCH_BEGIN
if [[ \$- == *i* && -n \${KITTY_WINDOW_ID:-} && -z \${GENTOO_RICE_FASTFETCH:-} ]] && command -v fastfetch >/dev/null; then
    export GENTOO_RICE_FASTFETCH=1
    fastfetch
fi
$FASTFETCH_END
EOF
ok "fastfetch beim Öffnen von kitty (~/.bashrc)"
DONE+=("Autostart Hyprland auf TTY1, fastfetch in kitty")

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
command -v flatpak >/dev/null || die "flatpak nicht verfügbar – Steam kann nicht installiert werden."
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
ok "Flathub (user) eingerichtet"
if flatpak info --user com.valvesoftware.Steam >/dev/null 2>&1; then
    ok "Steam bereits installiert"
else
    flatpak install --user -y --noninteractive flathub com.valvesoftware.Steam || die "Steam-Flatpak konnte nicht installiert werden."
fi
RT=$(flatpak info --user com.valvesoftware.Steam 2>/dev/null | awk -F/ '/Runtime:/{print $NF}')
if [[ -n $RT ]]; then
    flatpak install --user -y --noninteractive flathub "org.freedesktop.Platform.VulkanLayer.MangoHud//$RT" \
        && ok "MangoHud-Layer für Steam ($RT)" || warn "MangoHud-Flatpak-Layer nicht installiert"
fi
flatpak override --user --filesystem=xdg-config/MangoHud:ro --talk-name=com.feralinteractive.GameMode com.valvesoftware.Steam
ok "Steam installiert (Super+G)"
DONE+=("gamemode, mangohud, Flatpak + Flathub, Steam")

# ── Wallpaper Engine (optional) ────────────────────────────
if [[ $WE -eq 1 ]]; then
    step "Wallpaper Engine (linux-wallpaperengine)"
    "$REPO/scripts/wallpaperengine.sh" || die "Wallpaper-Engine-Setup fehlgeschlagen (einzeln: ./scripts/wallpaperengine.sh)."
    DONE+=("Wallpaper Engine: linux-wallpaperengine in ~/.local/bin")
fi

# ── Dev-Setup (optional) ───────────────────────────────────
if [[ $DEV -eq 1 ]]; then
    step "Entwickler-Setup"
    "$REPO/scripts/dev-setup.sh" || die "Dev-Setup fehlgeschlagen (einzeln: ./scripts/dev-setup.sh)."
    DONE+=("Dev-Setup: VS Code, Claude Code, Python, Dev-Tools")
fi

# ── 12. Fertig ─────────────────────────────────────────────
step "Abschluss"
fc-cache -f >/dev/null 2>&1 || true
ok "Alles erledigt"

printf '\n%s╭─ Zusammenfassung ─────────────────────────────╮%s\n' "$B" "$N"
for d in "${DONE[@]}"; do printf '  %s✔%s %s\n' "$G" "$N" "$d"; done
printf '%s╰───────────────────────────────────────────────╯%s\n' "$B" "$N"
if ((${#SKIPPED[@]})); then
    printf '\n%sÜbersprungen (nicht verfügbar):%s\n' "$Y$B" "$N"
    for s in "${SKIPPED[@]}"; do printf '  %s!%s %s\n' "$Y" "$N" "$s"; done
fi
printf '\n%sJetzt neu starten:%s %s\n' "$B$Y" "$N" "loginctl reboot"
printf '%sNach dem Login auf TTY1 startet Hyprland automatisch.%s\n' "$D" "$N"
printf '%sSteam in Spielen: Startoptionen  →  gamemoderun mangohud %%command%%%s\n\n' "$D" "$N"
if [[ -t 0 ]]; then
    read -r -p "Jetzt neu starten? [j/N] " a
    [[ $a =~ ^[jJyY]$ ]] && { loginctl reboot 2>/dev/null || $SUDO reboot; }
fi
exit 0

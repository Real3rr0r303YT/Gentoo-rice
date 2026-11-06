#!/usr/bin/env bash
# Gentoo-rice – Installer
# Copyright (C) 2026 3rr0r303YT
# This program is free software: GNU GPL-3.0-or-later (siehe LICENSE)
set -Eeuo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DEV=0 WE=0 DRY_RUN=0 CLAUDE=1 LOGIN=0 LOGIN_THEME=gentoo-rice
for arg in "$@"; do
    case $arg in
        --dev)     DEV=1 ;;
        --we)      WE=1 ;;
        --dry-run) DRY_RUN=1 ;;
        --no-claude) CLAUDE=0 ;;
        --login|--login=default|--login=gentoo-rice) LOGIN=1 LOGIN_THEME=gentoo-rice ;;
        --login=minecraft|--login=blocks) LOGIN=1 LOGIN_THEME=gentoo-rice-blocks ;;
        -h|--help)
            printf 'Nutzung: ./install.sh [--dev] [--we] [--login[=minecraft]] [--no-claude] [--dry-run]\n'
            printf '  --dev      zusätzlich Entwickler-Setup (scripts/dev-setup.sh)\n'
            printf '  --we       zusätzlich Wallpaper Engine (scripts/wallpaperengine.sh)\n'
            printf '  --login    grafischer Login-Screen (SDDM, Wayland); --login=minecraft für den Klötzchen-Look\n'
            printf '  --no-claude  Claude Code nicht installieren\n'
            printf '  --dry-run  nur anzeigen, was installiert/geändert würde (keine Änderungen)\n'
            exit 0 ;;
        *) printf 'Unbekannte Option: %s (siehe --help)\n' "$arg" >&2; exit 1 ;;
    esac
done

TOTAL=$((14 + CLAUDE + LOGIN + DEV + WE))
KW_FILE=/etc/portage/package.accept_keywords/gentoo-rice-auto
# shellcheck source=scripts/links.sh
source "$REPO/scripts/links.sh"
# shellcheck source=scripts/lib.sh
source "$REPO/scripts/lib.sh"

USER_NAME="$(id -un)"
DONE=()

# ── Paketlisten ────────────────────────────────────────────
# "a|b" = Alternativen (erstes verfügbares Paket wird genommen)
PKGS_BASE=( dev-vcs/git app-eselect/eselect-repository )
PKGS_DESKTOP=(
    gui-wm/hyprland gui-apps/hyprlock gui-apps/hypridle
    gui-libs/xdg-desktop-portal-hyprland sys-apps/xdg-desktop-portal sys-apps/xdg-desktop-portal-gtk
    gui-apps/waybar x11-misc/rofi gui-apps/mako x11-terms/kitty x11-misc/xdg-utils
    "gui-apps/awww|gui-apps/swww" gui-apps/mpvpaper media-video/mpv media-video/ffmpeg
    media-sound/playerctl gui-apps/grim gui-apps/slurp gui-apps/wl-clipboard
    app-misc/brightnessctl x11-libs/libnotify x11-misc/xdg-user-dirs
    gnome-base/dconf media-gfx/imagemagick net-misc/curl app-arch/xz-utils
    sys-auth/elogind sys-apps/dbus sys-auth/polkit
)
PKGS_TOYS=(
    app-misc/fastfetch media-sound/cava sys-process/btop
    "app-misc/cmatrix|games-misc/cmatrix|x11-misc/cmatrix"
    "app-misc/tty-clock|x11-misc/tty-clock|games-misc/tty-clock"
    "dev-python/pipx|app-misc/pipx"
)
PKGS_OPTIONAL=(
    gui-apps/hyprpolkitagent media-sound/pavucontrol xfce-base/thunar net-misc/networkmanager
    net-wireless/bluez net-wireless/blueman x11-themes/papirus-icon-theme
)
PKGS_FONTS=( media-fonts/jetbrains-mono media-fonts/fontawesome media-fonts/noto-emoji media-fonts/noto-cjk )
PKGS_FIREFOX=( www-client/firefox-bin )
PKGS_AUDIO=( media-video/pipewire media-video/wireplumber )
PKGS_GPU=( sys-kernel/linux-firmware dev-util/vulkan-tools x11-apps/mesa-progs )
PKGS_GPU_UPDATE=( media-libs/mesa media-libs/vulkan-loader x11-libs/libdrm media-libs/libva )
PKGS_GAMING=( games-util/gamemode games-util/mangohud sys-apps/flatpak )

# ── Portage-Konfiguration ──────────────────────────────────
read -r -d '' PORTAGE_VIDEO <<'EOF' || true
# Radeon 780M (RDNA3)
*/* VIDEO_CARDS: -* amdgpu radeonsi
EOF
read -r -d '' PORTAGE_USE <<'EOF' || true
# Gentoo-rice
media-libs/mesa vulkan vaapi
media-video/pipewire sound-server pipewire-alsa
media-video/wireplumber lua
# Waybar: Tray braucht libdbusmenu[gtk3], Media-Insel braucht mpris
gui-apps/waybar network pulseaudio tray mpris wifi upower logind udev
dev-libs/libdbusmenu gtk3
x11-libs/gtk+:3 wayland X
gui-libs/gtk wayland X
gui-wm/hyprland X
x11-terms/kitty wayland
x11-misc/rofi wayland
media-gfx/imagemagick png jpeg webp
media-sound/cava pulseaudio pipewire
media-video/mpv libmpv wayland vaapi pipewire lua
media-video/ffmpeg x264 vpx webp zlib vaapi opus
media-libs/libsdl2 wayland
games-util/mangohud wayland
sys-apps/flatpak policykit
sys-apps/xdg-desktop-portal policykit
dev-lang/python ensurepip sqlite
EOF
read -r -d '' PORTAGE_LICENSE <<'EOF' || true
sys-kernel/linux-firmware linux-fw-redistributable no-source-code
EOF

hypr_keywords() { # Keywords für alle hypr*-Pakete aller Repos (sortiert)
    local r p d cp e
    local -A kw=() from=()
    for r in $(portageq get_repos / 2>/dev/null); do
        p=$(repo_path "$r"); [[ -d $p ]] || continue
        for d in "$p"/*/hypr* "$p"/*/aquamarine "$p"/*/xdg-desktop-portal-hyprland; do
            { [[ -d $d ]] && compgen -G "$d/*.ebuild" >/dev/null; } || continue
            cp=${d#"$p"/}
            from[$cp]="${from[$cp]:+${from[$cp]},}$r"
            [[ ${kw[$cp]:-} == "~amd64" ]] || kw[$cp]="**"
            for e in "$d"/*.ebuild; do [[ $e == *-9999.ebuild ]] || { kw[$cp]="~amd64"; break; }; done
        done
    done
    for cp in "${!kw[@]}"; do printf '%-42s %-7s # %s\n' "$cp" "${kw[$cp]}" "${from[$cp]}"; done | sort
}
keywords_file() {
    echo "# Gentoo-rice – automatisch erzeugt von install.sh"
    echo "# Hyprland-Ökosystem (Repo-Herkunft als Kommentar)"
    hypr_keywords
    echo "# Abhängigkeiten / Gaming"
    printf '%-42s %s\n' dev-cpp/sdbus-c++ "~amd64" dev-cpp/glaze "~amd64" \
        games-util/mangohud "~amd64" games-util/gamemode "~amd64" \
        gui-apps/swww "~amd64" gui-apps/awww "~amd64" gui-apps/mpvpaper "~amd64"
}

# ── Dry-Run ────────────────────────────────────────────────
dry_run() {
    local spec a r group
    TOTAL=5
    printf '%s\n' "${B}Gentoo-rice – Dry-Run${N} ${D}(keine Änderungen, kein sudo)${N}"

    step "Repositories"
    for r in guru hyproverlay; do
        if repo_enabled "$r" && repo_synced "$r"; then ok "$r aktiv ($(repo_path "$r"))"
        elif repo_enabled "$r"; then warn "$r aktiv, aber nicht synchronisiert → emaint sync -r $r"
        elif [[ $r == guru ]]; then info "$r nicht aktiv → würde aktiviert + synchronisiert"
        else info "$r nicht aktiv (wird nur genutzt, falls Hyprland sonst fehlt)"; fi
    done
    r=$(pkg_repos gui-wm/hyprland)
    if [[ -n $r ]]; then ok "gui-wm/hyprland aus: ${r// /, }"
    else warn "gui-wm/hyprland in keinem aktiven Repo → install.sh würde ::gentoo syncen und ggf. hyproverlay aktivieren"; fi

    step "Pakete"
    for group in PKGS_BASE PKGS_DESKTOP PKGS_TOYS PKGS_OPTIONAL PKGS_FONTS PKGS_FIREFOX PKGS_AUDIO PKGS_GPU PKGS_GAMING; do
        local -n list=$group
        printf '  %s%s%s\n' "$B" "${group#PKGS_}" "$N"
        for spec in "${list[@]}"; do
            if ! a=$(resolve_spec "$spec"); then
                printf '    %s✘%s %-45s nicht verfügbar\n' "$R" "$N" "${spec//|/ | }"; SKIPPED+=("${spec//|/ oder }")
                if [[ $spec == *pipx* ]]; then printf '      %s→ Fallback: scripts/ensure-pipx.sh (venv bzw. pip --user)%s\n' "$D" "$N"; fi
            elif installed "$a"; then printf '    %s✔%s %-45s installiert\n' "$G" "$N" "$a"
            else
                r=$(pkg_repos "$a")
                if [[ -n $(portageq best_visible / ebuild "$a" 2>/dev/null) ]]; then
                    printf '    %s+%s %-45s wird installiert (%s)\n' "$C" "$N" "$a" "${r// /, }"
                else
                    printf '    %s+%s %-45s wird installiert (%s, braucht ~amd64)\n' "$Y" "$N" "$a" "${r// /, }"
                fi
                PLAN_NEW+=("$a")
            fi
        done
        unset -n list
    done
    info "Mesa/Vulkan-Update: ${PKGS_GPU_UPDATE[*]} (--update --newuse --deep)"

    step "Portage-Dateien"
    printf '%s\n' "$PORTAGE_VIDEO" | write_root /etc/portage/package.use/00-gentoo-rice-video
    printf '%s\n' "$PORTAGE_USE"   | write_root /etc/portage/package.use/gentoo-rice
    keywords_file                  | write_root /etc/portage/package.accept_keywords/gentoo-rice
    printf '%s\n' "$PORTAGE_LICENSE" | write_root /etc/portage/package.license/gentoo-rice
    grep -qE '^\s*de_DE\.UTF-8' /etc/locale.gen 2>/dev/null || info "würde de_DE.UTF-8 in /etc/locale.gen ergänzen"

    step "Weitere Aktionen"
    for entry in "${LINKS[@]}"; do info "Symlink ~/${entry#*|} → ${entry%%|*}"; done
    info "pywal16 per pipx, Bibata-Cursor + sptlrx von GitHub, Platzhalter-Wallpaper → $WALLPAPER_DIR"
    info "Firefox-Policies nach /etc/firefox/policies (+ /opt/firefox/distribution), Standardbrowser"
    info "Dienste: elogind (boot), dbus (default), bluetooth (default, falls bluez)"
    info "Flatpak: Flathub (user), com.valvesoftware.Steam, MangoHud-Vulkan-Layer"
    info "Proton/.exe: ${PROTON_FLATPAKS[*]}; .exe-Dateien öffnen mit Bottles"
    info "Themes: Standard lofi (Farben aus dem Wallpaper), Wechsel mit Super+Shift+T"
    info "Autostart: Hyprland auf TTY1 (~/.bash_profile), fastfetch in kitty (~/.bashrc)"
    if ((CLAUDE)); then info "Claude Code: nativer Installer (claude.ai/install.sh), PATH in ~/.bashrc, Super+K"; fi
    if ((LOGIN)); then info "Login-Screen: SDDM (Wayland/Weston), Theme $LOGIN_THEME, display-manager im Runlevel default, TTY1-Autostart entfällt"; fi
    if ((DEV)); then info "Dev-Setup: scripts/dev-setup.sh"; fi
    if ((WE)); then info "Wallpaper Engine: scripts/wallpaperengine.sh"; fi

    if ((${#PLAN_NEW[@]})); then
        step "emerge --pretend (Auszug, vollständig im Log)"
        local out
        out=$(emerge --pretend --verbose --noreplace --autounmask=y --autounmask-use=y --autounmask-license=y \
            "${PLAN_NEW[@]}" 2>&1) || true
        printf '%s\n' "$out" >> "$LOG"
        printf '%s\n' "$out" | grep -E '^\[(ebuild|binary)|USE changes|keyword changes|license changes|^[<>=~]?[a-z0-9-]+/[A-Za-z0-9_+.-]+ |no ebuilds|masked' | head -n 80 || true
        info "Hinweis: Pakete aus GURU/hyproverlay fehlen hier, solange die Repos nicht aktiv sind."
    fi
    print_problems
    printf '\n%sDry-Run beendet – nichts wurde geändert. Log: %s%s\n' "$B" "$LOG" "$N"
}

if [[ $DRY_RUN -eq 1 ]]; then dry_run; exit 0; fi

printf '%s\n' "${B}Gentoo-rice${N} ${D}– Hyprland Setup für $USER_NAME · Log: $LOG${N}"

# ── 1. Grundwerkzeuge ──────────────────────────────────────
step "Grundwerkzeuge (git, eselect-repository)"
emerge_pkgs "${PKGS_BASE[@]}"
{ command -v eselect >/dev/null && command -v git >/dev/null; } || die "git/eselect-repository konnten nicht installiert werden."
ok "git + eselect-repository vorhanden"
DONE+=("Grundwerkzeuge")

# ── 2. Repositories ────────────────────────────────────────
step "Repositories: GURU & Hyprland-Quelle"
ensure_repo guru || die "GURU konnte nicht aktiviert/synchronisiert werden (eselect repository enable guru && emaint sync -r guru)."
ok "GURU aktiv + synchronisiert ($(repo_path guru))"

if [[ -z $(pkg_repos gui-wm/hyprland) ]]; then
    warn "gui-wm/hyprland nicht gefunden – synchronisiere Gentoo-Hauptrepo"
    $SUDO emaint sync -r gentoo >>"$LOG" 2>&1 || warn "Sync von ::gentoo fehlgeschlagen"
fi
if [[ -z $(pkg_repos gui-wm/hyprland) ]]; then
    warn "gui-wm/hyprland weiterhin nicht gefunden – aktiviere hyproverlay"
    if ensure_repo hyproverlay; then ok "hyproverlay aktiv + synchronisiert"; else warn "hyproverlay konnte nicht eingerichtet werden"; fi
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
printf '%s\n' "$PORTAGE_VIDEO"   | write_root /etc/portage/package.use/00-gentoo-rice-video
printf '%s\n' "$PORTAGE_USE"     | write_root /etc/portage/package.use/gentoo-rice
keywords_file                    | write_root /etc/portage/package.accept_keywords/gentoo-rice
printf '%s\n' "$PORTAGE_LICENSE" | write_root /etc/portage/package.license/gentoo-rice
info "$(keywords_file | grep -c '^[a-z]' || true) Keyword-Einträge"

if ! grep -qE '^\s*de_DE\.UTF-8' /etc/locale.gen 2>/dev/null; then
    echo "de_DE.UTF-8 UTF-8" | $SUDO tee -a /etc/locale.gen >/dev/null
    $SUDO locale-gen >>"$LOG" 2>&1 || warn "locale-gen fehlgeschlagen"
    info "Locale de_DE.UTF-8 erzeugt"
fi
ok "Portage konfiguriert"
DONE+=("USE-Flags/Keywords/Lizenzen in /etc/portage/*/gentoo-rice")

# ── 4. Desktop-Pakete ──────────────────────────────────────
step "Hyprland & Desktop-Pakete"
emerge_pkgs "${PKGS_DESKTOP[@]}"
installed gui-wm/hyprland || die "Hyprland wurde nicht installiert – Details im Log ($LOG), Abschnitt gui-wm/hyprland."
emerge_pkgs "${PKGS_TOYS[@]}"
emerge_pkgs --optional "${PKGS_OPTIONAL[@]}"
ok "Desktop-Pakete installiert"
DONE+=("Hyprland, hyprlock, hypridle, Waybar, rofi, mako, kitty, swww, mpvpaper, cava, btop, cmatrix, tty-clock")

# ── 5. Fonts ───────────────────────────────────────────────
step "Fonts (JetBrains Mono, Font Awesome, Noto CJK/Emoji)"
emerge_pkgs "${PKGS_FONTS[@]}"
fc-cache -f >/dev/null 2>&1 || true
ok "Fonts installiert"
DONE+=("Fonts JetBrains Mono, Font Awesome, Noto CJK")

# ── 6. Themes ──────────────────────────────────────────────
step "Themes: Adwaita-dark, Papirus-Dark, Bibata-Cursor"
if [[ -d /usr/share/icons/Papirus-Dark || -d $HOME/.local/share/icons/Papirus-Dark ]]; then ok "Icons: Papirus-Dark"
else warn "Papirus-Dark nicht installiert (x11-themes/papirus-icon-theme)"; fi
# Bibata-Mauszeiger: Ice (weiß), Classic (schwarz), Amber – je nach Theme
mkdir -p "$HOME/.local/share/icons"
for cur in Bibata-Modern-Ice Bibata-Modern-Classic Bibata-Modern-Amber; do
    if [[ -d $HOME/.local/share/icons/$cur/cursors ]]; then ok "Cursor: $cur"; continue; fi
    tmp=$(mktemp -d)
    if curl -fsSL -o "$tmp/c.tar.xz" "https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/$cur.tar.xz" \
        && tar -xJf "$tmp/c.tar.xz" -C "$HOME/.local/share/icons"; then
        ok "Cursor: $cur"
    else
        warn "$cur konnte nicht geladen werden"; SKIPPED+=("$cur (Download)")
    fi
    rm -rf "$tmp"
done
"$REPO/scripts/cursor.sh" Bibata-Modern-Ice 24 >/dev/null || warn "Standard-Cursor bleibt"
DONE+=("Themes: Adwaita-dark, Papirus-Dark, Bibata-Cursor (Ice/Classic/Amber)")

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
# GTK-Farben des aktiven Themes (wal/templates/gtk-colors.css)
for entry in "${CACHE_LINKS[@]}"; do
    link_one "$HOME/${entry%%|*}" "${entry#*|}"
done
for entry in "${GENERATED_LINKS[@]}"; do
    ln -sfn "$HOME/${entry#*|}" "$REPO/${entry%%|*}"
done
[[ $backed -eq 1 ]] && DONE+=("Backup: $BACKUP") || true
"$REPO/scripts/hypr-version.sh"
xdg-user-dirs-update >/dev/null 2>&1 || true
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'          2>/dev/null || true
gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'         2>/dev/null || true
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'        2>/dev/null || true
gsettings set org.gnome.desktop.interface font-name 'JetBrains Mono 10'     2>/dev/null || true
gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrains Mono 11' 2>/dev/null || true
DONE+=("Configs verlinkt nach ~/.config")

# ── 8. Wallpaper & Farben ──────────────────────────────────
step "Wallpaper & dynamische Farben (pywal16)"
if command -v wal >/dev/null; then
    ok "pywal16 vorhanden"
elif "$REPO/scripts/ensure-pipx.sh" >>"$LOG" 2>&1 && pipx install pywal16 >>"$LOG" 2>&1; then
    ok "pywal16 installiert (pipx: $(command -v pipx))"
else
    warn "pywal16 nicht installierbar – festes Fallback-Farbschema wird genutzt"; FAILED+=("pywal16 (pipx)")
fi
mkdir -p "$WALLPAPER_DIR"
for f in "$REPO"/wallpapers/*.jpg; do
    [[ -e $WALLPAPER_DIR/$(basename "$f") ]] || { cp "$f" "$WALLPAPER_DIR/"; info "Wallpaper: $(basename "$f")"; }
done
"$REPO/scripts/wallpaper.sh" init || die "Farbschema konnte nicht erzeugt werden."
[[ -f $HOME/.cache/wal/colors-hyprland.conf ]] || die "$HOME/.cache/wal/colors-hyprland.conf fehlt."
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
        warn "sptlrx nicht installiert (optional)"; SKIPPED+=("sptlrx (Download, optional)")
    fi
    rm -rf "$tmp"
fi
DONE+=("Wallpaper in ~/Pictures/wallpapers, Farben via pywal16")

# ── 8. Firefox ─────────────────────────────────────────────
step "Firefox (Binärversion)"
emerge_pkgs "${PKGS_FIREFOX[@]}"
FF_BIN=$(command -v firefox-bin || command -v firefox || true)
if [[ -z $FF_BIN ]]; then
    warn "Firefox nicht installiert – Firefox-Einrichtung übersprungen"
else
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
fi
[[ $backed -eq 1 && ! " ${DONE[*]} " == *"Backup: $BACKUP"* ]] && DONE+=("Backup: $BACKUP") || true
DONE+=("Firefox (Standardbrowser, Policies, uBlock Origin, userChrome.css)")

# ── 8. Audio ───────────────────────────────────────────────
step "PipeWire + WirePlumber"
emerge_pkgs "${PKGS_AUDIO[@]}"
for g in audio video input pipewire seat gamemode plugdev; do
    if getent group "$g" >/dev/null && ! id -nG "$USER_NAME" | grep -w "$g" >/dev/null; then
        if $SUDO usermod -aG "$g" "$USER_NAME"; then info "Gruppe $g hinzugefügt"; else warn "usermod -aG $g fehlgeschlagen"; fi
    fi
done
SERVICES=(elogind:boot dbus:default)
[[ -x /etc/init.d/bluetooth ]] && SERVICES+=(bluetooth:default)
for svc in "${SERVICES[@]}"; do
    s=${svc%%:*}; lvl=${svc#*:}
    [[ -x /etc/init.d/$s ]] || { warn "Dienst $s nicht vorhanden"; continue; }
    if ! rc-update show "$lvl" 2>/dev/null | grep -w "$s" >/dev/null; then
        if $SUDO rc-update add "$s" "$lvl" >>"$LOG" 2>&1; then info "rc-update add $s $lvl"; else warn "rc-update add $s $lvl fehlgeschlagen"; fi
    fi
done
command -v gentoo-pipewire-launcher >/dev/null || warn "gentoo-pipewire-launcher fehlt (media-video/pipewire mit USE=sound-server?)"
ok "PipeWire startet mit Hyprland (gentoo-pipewire-launcher)"
DONE+=("PipeWire/WirePlumber")

# ── 9. Autostart ───────────────────────────────────────────
step "Hyprland-Autostart auf TTY1"
if [[ $LOGIN -eq 1 || -f $LOGIN_MARKER ]]; then
    # Login-Screen übernimmt den Start – TTY1-Autostart würde Hyprland doppelt starten
    info "Login-Screen aktiv – kein TTY1-Autostart"
else
    for prof in "$HOME/.bash_profile" "$HOME/.zprofile"; do
        [[ $prof == *zprofile && ! -f $prof ]] && continue
        touch "$prof"
        if grep -qF "$PROFILE_BEGIN" "$prof"; then
            sed -i "/$PROFILE_BEGIN/,/$PROFILE_END/d" "$prof"
        fi
        printf '\n%s\n' "$PROFILE_SNIPPET" >> "$prof"
        ok "Autostart in ${prof/#$HOME/\~}"
    done
fi
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
emerge_pkgs "${PKGS_GPU[@]}"
# VIDEO_CARDS geändert → Mesa & Co. mit neuen Flags neu bauen
info "Mesa/Vulkan-Update (--update --newuse --deep) …"
$SUDO "${EMERGE_BASE[@]}" "${AUTOUNMASK_WRITE[@]/--noreplace/--update}" --newuse --deep "${PKGS_GPU_UPDATE[@]}" >>"$LOG" 2>&1 || true
$SUDO etc-update --automode -5 /etc/portage >>"$LOG" 2>&1 || true
if $SUDO "${EMERGE_BASE[@]}" "${EMERGE_OPTS[@]/--noreplace/--update}" --newuse --deep "${PKGS_GPU_UPDATE[@]}"; then
    ok "Mesa (radeonsi + RADV) aktuell"
else
    warn "Mesa/Vulkan-Update mit Fehlern"; FAILED+=("Mesa/Vulkan-Update (${PKGS_GPU_UPDATE[*]})")
fi
command -v vulkaninfo >/dev/null && info "Test: vulkaninfo --summary"
DONE+=("Mesa/Vulkan (RADV) für Radeon 780M")

# ── 11. Gaming ─────────────────────────────────────────────
step "Gaming: gamemode, mangohud, Flatpak, Steam"
emerge_pkgs "${PKGS_GAMING[@]}"
if ! command -v flatpak >/dev/null; then
    warn "flatpak nicht verfügbar – Steam übersprungen"; FAILED+=("Steam (flatpak fehlt)")
elif ! flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo; then
    warn "Flathub konnte nicht eingerichtet werden"; FAILED+=("Flathub")
else
    ok "Flathub (user) eingerichtet"
    if flatpak info --user com.valvesoftware.Steam >/dev/null 2>&1; then
        ok "Steam bereits installiert"
    elif flatpak install --user -y --noninteractive flathub com.valvesoftware.Steam; then
        ok "Steam installiert (Super+G)"
    else
        warn "Steam-Flatpak konnte nicht installiert werden"; FAILED+=("com.valvesoftware.Steam (Flatpak)")
    fi
    RT=$(flatpak info --user com.valvesoftware.Steam 2>/dev/null | awk -F/ '/Runtime:/{print $NF}' || true)
    if [[ -n $RT ]]; then
        if flatpak install --user -y --noninteractive flathub "org.freedesktop.Platform.VulkanLayer.MangoHud//$RT"; then
            ok "MangoHud-Layer für Steam ($RT)"
        else
            warn "MangoHud-Flatpak-Layer nicht installiert"; FAILED+=("org.freedesktop.Platform.VulkanLayer.MangoHud//$RT")
        fi
        flatpak override --user --filesystem=xdg-config/MangoHud:ro --talk-name=com.feralinteractive.GameMode \
            com.valvesoftware.Steam || warn "flatpak override fehlgeschlagen"
    fi

    # Proton & .exe-Spiele: Proton-GE für Steam, ProtonUp-Qt, Bottles
    for app in "${PROTON_FLATPAKS[@]}"; do
        if flatpak info --user "$app" >/dev/null 2>&1; then ok "$app vorhanden"
        elif flatpak install --user -y --noninteractive flathub "$app"; then ok "$app installiert"
        else warn "$app nicht installiert"; FAILED+=("$app (Flatpak)"); fi
    done
    # .exe-Dateien per Doppelklick mit Bottles öffnen
    if flatpak info --user com.usebottles.bottles >/dev/null 2>&1; then
        if xdg-mime default com.usebottles.bottles.desktop application/x-ms-dos-executable \
            application/x-msdownload application/vnd.microsoft.portable-executable application/x-msi 2>/dev/null; then
            ok ".exe/.msi → Bottles"
        else
            warn "xdg-mime für .exe fehlgeschlagen"
        fi
        # Bottles darf Spiele aus dem Home-Ordner und von weiteren Laufwerken starten
        flatpak override --user --filesystem=home --filesystem=/run/media com.usebottles.bottles || true
    fi
fi
DONE+=("gamemode, mangohud, Flatpak + Flathub, Steam, Proton-GE, ProtonUp-Qt, Bottles")

# ── Claude Code ────────────────────────────────────────────
if [[ $CLAUDE -eq 1 ]]; then
    step "Claude Code (nativer Installer)"
    if out=$("$REPO/scripts/install-claude-code.sh" 2>&1); then
        while IFS= read -r l; do info "$l"; done <<<"$out"
        ok "Claude Code bereit – im Terminal: claude  ·  Taste: Super+K"
        DONE+=("Claude Code ($(claude --version 2>/dev/null || echo installiert))")
    else
        printf '%s\n' "$out" >> "$LOG"
        warn "Claude Code konnte nicht installiert werden"; FAILED+=("Claude Code (einzeln: ./scripts/install-claude-code.sh)")
    fi
fi

# ── Login-Screen (optional) ────────────────────────────────
if [[ $LOGIN -eq 1 ]]; then
    step "Login-Screen (SDDM)"
    if "$REPO/scripts/login-screen.sh" --theme "$LOGIN_THEME"; then
        DONE+=("Login-Screen: SDDM mit Theme $LOGIN_THEME (Notausgang: Strg+Alt+F2 → sudo rc-update del display-manager)")
    else
        warn "Login-Screen-Einrichtung fehlgeschlagen – TTY1-Autostart wird wieder eingetragen"
        FAILED+=("Login-Screen (einzeln: ./scripts/login-screen.sh)")
        if [[ ! -f $LOGIN_MARKER ]] && ! grep -qF "$PROFILE_BEGIN" "$HOME/.bash_profile" 2>/dev/null; then
            printf '\n%s\n' "$PROFILE_SNIPPET" >> "$HOME/.bash_profile"
            ok "TTY1-Autostart in ~/.bash_profile"
        fi
    fi
fi

# ── Wallpaper Engine (optional) ────────────────────────────
if [[ $WE -eq 1 ]]; then
    step "Wallpaper Engine (linux-wallpaperengine)"
    if "$REPO/scripts/wallpaperengine.sh"; then DONE+=("Wallpaper Engine: linux-wallpaperengine in ~/.local/bin")
    else warn "Wallpaper-Engine-Setup fehlgeschlagen"; FAILED+=("Wallpaper Engine (einzeln: ./scripts/wallpaperengine.sh)"); fi
fi

# ── Dev-Setup (optional) ───────────────────────────────────
if [[ $DEV -eq 1 ]]; then
    step "Entwickler-Setup"
    if "$REPO/scripts/dev-setup.sh"; then DONE+=("Dev-Setup: VS Code, Claude Code, Python, Dev-Tools")
    else warn "Dev-Setup fehlgeschlagen"; FAILED+=("Dev-Setup (einzeln: ./scripts/dev-setup.sh)"); fi
fi

# ── 12. Fertig ─────────────────────────────────────────────
step "Abschluss"
fc-cache -f >/dev/null 2>&1 || true
ok "Alles erledigt"

printf '\n%s╭─ Zusammenfassung ─────────────────────────────╮%s\n' "$B" "$N"
for d in "${DONE[@]}"; do printf '  %s✔%s %s\n' "$G" "$N" "$d"; done
printf '%s╰───────────────────────────────────────────────╯%s\n' "$B" "$N"
print_problems
printf '\n%sLog:%s %s\n' "$B" "$N" "$LOG"
printf '\n%sJetzt neu starten:%s %s\n' "$B$Y" "$N" "loginctl reboot"
printf '%sNach dem Login auf TTY1 startet Hyprland automatisch.%s\n' "$D" "$N"
printf '%sSteam in Spielen: Startoptionen  →  gamemoderun mangohud %%command%%%s\n\n' "$D" "$N"
if [[ -t 0 ]]; then
    read -r -p "Jetzt neu starten? [j/N] " a || a=""
    if [[ $a =~ ^[jJyY]$ ]]; then loginctl reboot 2>/dev/null || $SUDO reboot; fi
fi
exit 0

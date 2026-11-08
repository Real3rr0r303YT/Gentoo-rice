#!/usr/bin/env bash
# Gentoo-rice – Rice (und optional das System) aktualisieren
# Copyright (C) 2026 3rr0r303YT – GPL-3.0-or-later
#
# Nutzung: ./scripts/update.sh            Rice: git pull, Links prüfen, Farben, Hyprland/Waybar/mako neu laden;
#                                         installiert Hyprland (+ hyprlock, hypridle, Portal), falls es fehlt
#          ./scripts/update.sh --system   zusätzlich: Hyprland auf die neueste Version, Portage-Sync,
#                                         emerge @world + Flatpaks
set -Eeuo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SYSTEM=0
for arg in "$@"; do
    case $arg in
        --system) SYSTEM=1 ;;
        -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
        *) printf 'Unbekannte Option: %s\n' "$arg" >&2; exit 1 ;;
    esac
done

# Hyprland-Kern: wird installiert, falls etwas fehlt (mit --system auch aktualisiert)
HYPR_PKGS=(gui-wm/hyprland gui-apps/hyprlock gui-apps/hypridle gui-libs/xdg-desktop-portal-hyprland)
HYPR_MISSING=()
for p in "${HYPR_PKGS[@]}"; do
    portageq has_version / "$p" 2>/dev/null || HYPR_MISSING+=("$p")
done
HYPR_STEP=0
if ((SYSTEM)) || ((${#HYPR_MISSING[@]})); then HYPR_STEP=1; fi

TOTAL=$((4 + HYPR_STEP + SYSTEM * 2)) STEP_LABEL=update KW_FILE=/etc/portage/package.accept_keywords/gentoo-rice-auto
# sudo nur, wenn emerge gebraucht wird → sonst keine Passwortabfrage
if ((HYPR_STEP == 0)); then export GENTOO_RICE_SUDO_LOOP=1; fi
# shellcheck source=scripts/links.sh
source "$REPO/scripts/links.sh"
# shellcheck source=scripts/lib.sh
source "$REPO/scripts/lib.sh"

printf '%s\n' "${B}Gentoo-rice${N} ${D}– Update${N}"

# ── 1. Rice von GitHub ────────────────────────────────────
step "Rice aktualisieren (git)"
cd "$REPO"
before=$(git rev-parse --short HEAD)
branch=$(git branch --show-current)
if [[ -n $(git status --porcelain --untracked-files=no) ]]; then
    warn "Lokale Änderungen im Repo – werden vorübergehend beiseitegelegt (git stash)"
    git stash push -q -m "gentoo-rice update $(date +%F_%T)"
    info "Zurückholen mit: git stash pop"
fi
# Automatisch erzeugte Standard-Config von Hyprland würde den Pull blockieren
if ! git ls-files --error-unmatch hypr/hyprland.lua >/dev/null 2>&1 && [[ -f hypr/hyprland.lua ]]; then
    mv hypr/hyprland.lua "hypr/hyprland.lua.auto-$(date +%s)"
fi
git fetch -q origin
# Alter, bereits gemergter Feature-Branch → auf main wechseln; sonst den aktuellen Branch aktualisieren
if [[ $branch != main ]] && git merge-base --is-ancestor HEAD origin/main; then
    info "'$branch' ist bereits in main enthalten – wechsle auf main"
    git checkout -q main
    branch=main
fi
if git rev-parse -q --verify "origin/$branch" >/dev/null; then
    git pull -q --ff-only origin "$branch" || die "git pull fehlgeschlagen (lokale Commits?). Details: git status"
else
    warn "Branch '$branch' gibt es auf GitHub nicht – bleibe auf dem lokalen Stand"
fi
after=$(git rev-parse --short HEAD)
if [[ $before == "$after" ]]; then ok "bereits aktuell ($after)"
else ok "$before → $after"; git --no-pager log --oneline "$before..$after" | sed 's/^/    /' | head -15; fi

# ── Hyprland installieren / aktualisieren ─────────────────
if ((HYPR_STEP)); then
    step "Hyprland installieren/aktualisieren"
    as_dir package.accept_keywords
    keywords_file | write_root /etc/portage/package.accept_keywords/gentoo-rice
    if ((${#HYPR_MISSING[@]})); then
        info "fehlt: ${HYPR_MISSING[*]}"
        emerge_pkgs "${HYPR_MISSING[@]}"
    fi
    if ((SYSTEM)); then
        info "Hyprland-Pakete auf die neueste Version …"
        $SUDO emaint sync -a >>"$LOG" 2>&1 || warn "emaint sync mit Fehlern (Details im Log)"
        keywords_file | write_root /etc/portage/package.accept_keywords/gentoo-rice
        $SUDO "${EMERGE_BASE[@]}" "${AUTOUNMASK_WRITE[@]/--noreplace/--update}" --newuse "${HYPR_PKGS[@]}" >>"$LOG" 2>&1 || true
        $SUDO etc-update --automode -5 /etc/portage >>"$LOG" 2>&1 || true
        if ! $SUDO "${EMERGE_BASE[@]}" "${EMERGE_OPTS[@]/--noreplace/--update}" --newuse "${HYPR_PKGS[@]}"; then
            warn "Hyprland-Update mit Fehlern"; FAILED+=("Hyprland-Update (Details: $LOG)")
        fi
    fi
    if portageq has_version / gui-wm/hyprland 2>/dev/null; then
        ok "$(Hyprland --version 2>/dev/null | head -n1 || echo 'Hyprland installiert')"
    else
        warn "Hyprland ist nicht installiert – Details im Log"; FAILED+=("gui-wm/hyprland")
    fi
fi

# ── 2. Links & generierte Dateien ─────────────────────────
step "Config-Links prüfen"
missing=0
for entry in "${LINKS[@]}"; do
    src="$REPO/${entry%%|*}"; src="${src%/.}"
    dst="$HOME/${entry#*|}"
    if [[ -L $dst && "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]]; then continue; fi
    if [[ ! -e $dst && ! -L $dst ]]; then
        mkdir -p "$(dirname "$dst")"; ln -s "$src" "$dst"; ok "neu verlinkt: ~/${entry#*|}"
    else
        warn "$dst ist kein Link auf das Repo – ./install.sh sichert und verlinkt es"; missing=1
    fi
done
for entry in "${GENERATED_LINKS[@]}"; do ln -sfn "$HOME/${entry#*|}" "$REPO/${entry%%|*}"; done
for entry in "${CACHE_LINKS[@]}"; do
    dst="$HOME/${entry#*|}"
    [[ -e $dst || -L $dst ]] || { mkdir -p "$(dirname "$dst")"; ln -s "$HOME/${entry%%|*}" "$dst"; }
done
"$REPO/scripts/hypr-version.sh" || true
((missing)) || ok "alle Links in Ordnung"

# ── 3. Farben, Login-Screen, Zeiger ───────────────────────
step "Farben & Login-Screen angleichen"
theme=$("$REPO/scripts/theme.sh" current 2>/dev/null || echo lofi)
if [[ -f $HOME/.cache/rice/theme ]]; then
    "$REPO/scripts/theme.sh" set "$theme" >/dev/null 2>&1 || warn "Theme $theme konnte nicht gesetzt werden"
else
    "$REPO/scripts/wallpaper.sh" colors >/dev/null 2>&1 || warn "Farben konnten nicht erzeugt werden"
fi
"$REPO/scripts/sddm-sync.sh" >/dev/null 2>&1 || true
ok "Theme: $theme"

# ── 4. Laufende Sitzung neu laden ─────────────────────────
step "Hyprland, Waybar, mako neu laden"
if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
    if hyprctl reload >/dev/null 2>&1; then ok "Hyprland-Config neu geladen"; else warn "hyprctl reload fehlgeschlagen"; fi
    pkill -x waybar 2>/dev/null || true
    (waybar >/dev/null 2>&1 &)
    ok "Waybar neu gestartet"
    if pgrep -x mako >/dev/null; then makoctl reload 2>/dev/null || true; fi
    errs=$(hyprctl configerrors 2>/dev/null | grep -v '^$' || true)
    if [[ -n $errs && $errs != *"no errors"* ]]; then warn "Hyprland meldet Config-Fehler:"; printf '%s\n' "$errs" | sed 's/^/    /'; fi
else
    info "Nicht in Hyprland – Änderungen greifen beim nächsten Login"
fi

# ── 5./6. System (optional) ───────────────────────────────
if ((SYSTEM)); then
    step "Gentoo aktualisieren (@world)"
    if $SUDO "${EMERGE_BASE[@]}" --update --deep --newuse --getbinpkg --binpkg-respect-use=y --keep-going=y \
        --autounmask=y --autounmask-use=y --autounmask-license=y --autounmask-continue=y --quiet-build=y @world; then
        ok "@world aktuell"
    else
        warn "emerge @world mit Fehlern"; FAILED+=("emerge @world (Details: $LOG)")
    fi
    $SUDO etc-update --automode -5 /etc/portage >>"$LOG" 2>&1 || true
    info "Konfig-Updates außerhalb von /etc/portage prüfen: sudo dispatch-conf"
    Hyprland --version 2>/dev/null | head -n1 | sed 's/^/  · /' || true
    "$REPO/scripts/hypr-version.sh" || true

    step "Flatpaks (Steam, Spotify, Minecraft …)"
    if command -v flatpak >/dev/null; then
        if flatpak update --user -y --noninteractive >>"$LOG" 2>&1; then ok "Flatpaks aktuell"; else warn "flatpak update mit Fehlern"; fi
        # Spotify-Updates entfernen Spicetify → neu anwenden
        if command -v spicetify >/dev/null || [[ -x $HOME/.local/bin/spicetify ]]; then
            if "$REPO/scripts/apps.sh" spicetify >>"$LOG" 2>&1; then ok "Spicetify neu angewendet"; else warn "Spicetify: ./scripts/apps.sh spicetify"; fi
        fi
    else
        info "flatpak nicht installiert"
    fi
    info "Nach Kernel-/Hyprland-Updates neu starten: loginctl reboot"
fi

print_problems
printf '\n%sUpdate fertig.%s Log: %s\n' "$G$B" "$N" "$LOG"

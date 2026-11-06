# shellcheck shell=bash
# Gentoo-rice – gemeinsame Helfer für scripts/dev-setup.sh und scripts/wallpaperengine.sh
# Vor dem Einbinden optional setzen: TOTAL, STEP_LABEL, KW_FILE
# Copyright (C) 2026 3rr0r303YT – GPL-3.0-or-later

# ── Ausgabe ────────────────────────────────────────────────
if [[ -t 1 ]]; then
    B=$'\e[1m'; D=$'\e[2m'; R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; C=$'\e[36m'; N=$'\e[0m'
else
    B=; D=; R=; G=; Y=; C=; N=
fi
TOTAL=${TOTAL:-1}; STEP=0; CURRENT="Start"; STEP_LABEL=${STEP_LABEL:-}
SKIPPED=()
step() { STEP=$((STEP + 1)); CURRENT="$*"; printf '\n%s[%s%d/%d]%s %s%s%s\n' "$C$B" "${STEP_LABEL:+$STEP_LABEL }" "$STEP" "$TOTAL" "$N" "$B" "$*" "$N"; }
info() { printf '  %s•%s %s\n' "$D" "$N" "$*"; }
ok()   { printf '  %s✔%s %s\n' "$G" "$N" "$*"; }
warn() { printf '  %s!%s %s\n' "$Y" "$N" "$*"; }
die()  { printf '\n%s✘ Fehler:%s %s\n' "$R$B" "$N" "$*" >&2; exit 1; }
trap 'rc=$?; printf "\n%s✘ Abbruch in Schritt %d (%s), Befehl: %s (Exit %d)%s\n" "$R$B" "$STEP" "$CURRENT" "$BASH_COMMAND" "$rc" "$N" >&2; exit $rc' ERR

# ── Vorprüfung ─────────────────────────────────────────────
[[ -f /etc/gentoo-release ]] && command -v emerge >/dev/null || die "Dieses Skript läuft nur auf Gentoo Linux."
[[ $EUID -ne 0 ]] || die "Bitte als normaler Benutzer starten (nicht als root)."
if command -v sudo >/dev/null; then SUDO=sudo
elif command -v doas >/dev/null; then SUDO=doas
else die "Weder sudo noch doas gefunden."
fi
if [[ $SUDO == sudo ]]; then
    sudo -v || die "sudo-Authentifizierung fehlgeschlagen."
    ( while kill -0 $$ 2>/dev/null; do sudo -n true; sleep 50; done ) 2>/dev/null &
fi
export PATH="$HOME/.local/bin:$PATH"

# ── Helfer ─────────────────────────────────────────────────
KW_FILE=${KW_FILE:-/etc/portage/package.accept_keywords/gentoo-rice-extra}
EMERGE=(env CONFIG_PROTECT_MASK=/etc/portage emerge --noreplace --getbinpkg --binpkg-respect-use=y
        --autounmask=y --autounmask-continue=y --quiet-build=y)

as_dir() {
    local p=/etc/portage/$1
    if [[ -f $p ]]; then $SUDO mv "$p" "$p.tmp"; $SUDO mkdir -p "$p"; $SUDO mv "$p.tmp" "$p/00-original"; fi
    $SUDO mkdir -p "$p"
}
write_root() { # write_root <datei>  (stdin, nur bei Änderung)
    local f=$1 tmp; tmp=$(mktemp)
    cat > "$tmp"
    if ! $SUDO cmp -s "$tmp" "$f" 2>/dev/null; then
        $SUDO install -D -m 0644 "$tmp" "$f"; info "geschrieben: $f"
    fi
    rm -f "$tmp"
}
add_line_root() { # add_line_root <datei> <zeile>  (idempotent)
    $SUDO touch "$1"
    $SUDO grep -qxF "$2" "$1" || { echo "$2" | $SUDO tee -a "$1" >/dev/null; info "+ $2"; }
}
repo_path() { local p; p=$(portageq get_repo_path / "$1" 2>/dev/null) || true; echo "${p:-/var/db/repos/$1}"; }
pkg_exists() { # Ebuild in irgendeinem Repo?
    local r
    for r in $(portageq get_repos / 2>/dev/null); do
        compgen -G "$(repo_path "$r")/$1/*.ebuild" >/dev/null && return 0
    done
    return 1
}
pick() { # pick <atom> [alternative…]  → erstes existierendes Atom
    local a
    for a in "$@"; do pkg_exists "$a" && { echo "$a"; return 0; }; done
    return 1
}
installed() { portageq has_version / "$1" 2>/dev/null; }
pkg_check() { # 0 = installierbar
    local out
    installed "$1" && return 0
    pkg_exists "$1" || return 1
    # nur ~amd64 vorhanden → Keyword freigeben
    [[ -n $(portageq best_visible / ebuild "$1" 2>/dev/null) ]] || add_line_root "$KW_FILE" "$1 ~amd64"
    out=$($SUDO emerge -p --quiet --autounmask=y --autounmask-continue=n "$1" 2>&1) && return 0
    grep -qE 'there are no ebuilds (to satisfy|built with USE)|have been masked|is not a valid package atom|is ambiguous' <<<"$out" && return 1
    return 0
}
emerge_pkgs() { # emerge_pkgs "<atom>[|alternative…]" …
    local spec a todo=()
    for spec in "$@"; do
        # shellcheck disable=SC2086
        if a=$(pick ${spec//|/ }) && pkg_check "$a"; then todo+=("$a")
        else warn "nicht verfügbar, übersprungen: ${spec//|/ oder }"; SKIPPED+=("${spec%%|*}"); fi
    done
    ((${#todo[@]})) || return 0
    info "emerge: ${todo[*]}"
    $SUDO "${EMERGE[@]}" "${todo[@]}" || die "emerge fehlgeschlagen für: ${todo[*]}
   Details: emerge -av ${todo[*]}"
}
bashrc_block() { # bashrc_block <name> <inhalt>  – Block mit Markern in ~/.bashrc (ersetzt alten)
    local begin="# >>> gentoo-rice $1 >>>" end="# <<< gentoo-rice $1 <<<" f="$HOME/.bashrc"
    touch "$f"
    grep -qF "$begin" "$f" && sed -i "/$begin/,/$end/d" "$f"
    printf '%s\n%s\n%s\n' "$begin" "$2" "$end" >> "$f"
}

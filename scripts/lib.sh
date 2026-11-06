# shellcheck shell=bash
# Gentoo-rice – gemeinsame Helfer für install.sh, scripts/dev-setup.sh und scripts/wallpaperengine.sh
# Vor dem Einbinden optional setzen: TOTAL, STEP_LABEL, KW_FILE, DRY_RUN (0/1)
# Copyright (C) 2026 3rr0r303YT – GPL-3.0-or-later

DRY_RUN=${DRY_RUN:-0}
TOTAL=${TOTAL:-1}; STEP=0; CURRENT="Start"; STEP_LABEL=${STEP_LABEL:-}
KW_FILE=${KW_FILE:-/etc/portage/package.accept_keywords/gentoo-rice-extra}

# ── Ausgabe & Log ──────────────────────────────────────────
if [[ -t 1 || ${GENTOO_RICE_COLOR:-0} == 1 ]]; then
    B=$'\e[1m'; D=$'\e[2m'; R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; C=$'\e[36m'; N=$'\e[0m'
    export GENTOO_RICE_COLOR=1
else
    B=; D=; R=; G=; Y=; C=; N=
fi
LOG_DIR="$HOME/.cache/gentoo-rice"
LOG="$LOG_DIR/install.log"
if [[ -z ${GENTOO_RICE_LOGGING:-} ]]; then
    mkdir -p "$LOG_DIR"
    printf '\n===== %s  %s =====\n' "$(date '+%F %T')" "$(basename "$0")" >> "$LOG"
    exec > >(tee -a "$LOG") 2>&1
    export GENTOO_RICE_LOGGING=1
fi

step() { STEP=$((STEP + 1)); CURRENT="$*"; printf '\n%s[%s%d/%d]%s %s%s%s\n' "$C$B" "${STEP_LABEL:+$STEP_LABEL }" "$STEP" "$TOTAL" "$N" "$B" "$*" "$N"; }
info() { printf '  %s•%s %s\n' "$D" "$N" "$*"; }
ok()   { printf '  %s✔%s %s\n' "$G" "$N" "$*"; }
warn() { printf '  %s!%s %s\n' "$Y" "$N" "$*"; }
die()  { printf '\n%s✘ Fehler:%s %s\n  Log: %s\n' "$R$B" "$N" "$*" "$LOG" >&2; exit 1; }
# shellcheck disable=SC2154  # rc wird im Trap selbst gesetzt
trap 'rc=$?; printf "\n%s✘ Abbruch in Schritt %d (%s), Befehl: %s (Exit %d)%s\n  Log: %s\n" "$R$B" "$STEP" "$CURRENT" "$BASH_COMMAND" "$rc" "$N" "$LOG" >&2; exit $rc' ERR

# ── Vorprüfung ─────────────────────────────────────────────
{ [[ -f /etc/gentoo-release ]] && command -v emerge >/dev/null; } || die "Dieses Skript läuft nur auf Gentoo Linux."
[[ $EUID -ne 0 ]] || die "Bitte als normaler Benutzer starten (nicht als root) – sudo wird bei Bedarf genutzt."
if command -v sudo >/dev/null; then SUDO=sudo
elif command -v doas >/dev/null; then SUDO=doas
else die "Weder sudo noch doas gefunden. Als root: emerge app-admin/sudo und den Benutzer in /etc/sudoers eintragen."
fi
if [[ $DRY_RUN -eq 0 && $SUDO == sudo && -z ${GENTOO_RICE_SUDO_LOOP:-} ]]; then
    sudo -v || die "sudo-Authentifizierung fehlgeschlagen."
    ( while kill -0 $$ 2>/dev/null; do sudo -n true; sleep 50; done ) 2>/dev/null &
    export GENTOO_RICE_SUDO_LOOP=1
fi
export PATH="$HOME/.local/bin:$PATH"

# ── emerge ─────────────────────────────────────────────────
# CONFIG_PROTECT_MASK: autounmask schreibt direkt nach /etc/portage (keine ._cfg-Dateien)
EMERGE_BASE=(env CONFIG_PROTECT_MASK=/etc/portage emerge)
EMERGE_OPTS=(--noreplace --getbinpkg --binpkg-respect-use=y --quiet-build=y --keep-going=y
             --autounmask=y --autounmask-use=y --autounmask-license=y --autounmask-continue=y)
AUTOUNMASK_WRITE=(--noreplace --autounmask=y --autounmask-use=y --autounmask-license=y
                  --autounmask-write=y --autounmask-only=y)
SKIPPED=()   # nicht verfügbar
FAILED=()    # Installation fehlgeschlagen
PLAN_NEW=()  # Dry-Run: würde installiert
PLAN_HAVE=() # Dry-Run: bereits installiert

repo_path()    { local p; p=$(portageq get_repo_path / "$1" 2>/dev/null) || true; echo "${p:-/var/db/repos/$1}"; }
repo_enabled() { eselect repository list -i 2>/dev/null | grep -w -- "$1" >/dev/null; }
repo_synced()  { local p; p=$(repo_path "$1"); [[ -d $p && -d $p/metadata && -n "$(ls -A "$p" 2>/dev/null)" ]]; }
pkg_repos() { # Repos, die Ebuilds für <cat/pkg> enthalten
    local r out=()
    for r in $(portageq get_repos / 2>/dev/null); do
        compgen -G "$(repo_path "$r")/$1/*.ebuild" >/dev/null && out+=("$r")
    done
    echo "${out[*]}"
}
installed()  { portageq has_version / "$1" 2>/dev/null; }
pkg_exists() { [[ -n $(pkg_repos "$1") ]]; }

ensure_repo() { # aktivieren + syncen, falls nötig
    if ! repo_enabled "$1"; then
        $SUDO eselect repository enable "$1" >/dev/null || return 1
        info "$1 aktiviert"
    fi
    if ! repo_synced "$1"; then
        info "synchronisiere $1 …"
        $SUDO emaint sync -r "$1" >>"$LOG" 2>&1 || return 1
    fi
    repo_synced "$1"
}

resolve_spec() { # "<atom>[|alternative…]" → erstes installierte oder verfügbare Atom
    local a
    for a in ${1//|/ }; do installed "$a" && { echo "$a"; return 0; }; done
    for a in ${1//|/ }; do pkg_exists "$a" && { echo "$a"; return 0; }; done
    return 1
}

as_dir() { # /etc/portage/package.* in Verzeichnisform sicherstellen
    local p=/etc/portage/$1
    [[ $DRY_RUN -eq 1 ]] && return 0
    if [[ -f $p ]]; then $SUDO mv "$p" "$p.tmp"; $SUDO mkdir -p "$p"; $SUDO mv "$p.tmp" "$p/00-original"; fi
    $SUDO mkdir -p "$p"
}
write_root() { # write_root <datei>  (Inhalt von stdin, nur bei Änderung)
    local f=$1 tmp; tmp=$(mktemp)
    cat > "$tmp"
    if ! cmp -s "$tmp" "$f" 2>/dev/null; then
        if [[ $DRY_RUN -eq 1 ]]; then info "würde schreiben: $f"
        else
            $SUDO install -D -m 0644 "$tmp" "$f"
            info "geschrieben: $f"
        fi
    fi
    rm -f "$tmp"
}
add_line_root() { # add_line_root <datei> <zeile>  (idempotent)
    [[ -f $1 ]] && grep -qxF "$2" "$1" && return 0
    if [[ $DRY_RUN -eq 1 ]]; then info "würde eintragen: $2 → $1"; return 0; fi
    $SUDO mkdir -p "$(dirname "$1")"
    echo "$2" | $SUDO tee -a "$1" >/dev/null
    info "+ $2 → $(basename "$1")"
}
ensure_keyword() { # Nur ~amd64 (oder nur Live-Ebuilds) vorhanden → Keyword freigeben
    local atom=$1 r e kw="**"
    installed "$atom" && return 0
    [[ -n $(portageq best_visible / ebuild "$atom" 2>/dev/null) ]] && return 0
    for r in $(pkg_repos "$atom"); do
        for e in "$(repo_path "$r")/$atom"/*.ebuild; do [[ $e == *-9999.ebuild ]] || { kw="~amd64"; break 2; }; done
    done
    add_line_root "$KW_FILE" "$atom $kw"
}

# emerge_pkgs [--optional] "<atom>[|alternative…]" …
#   1. Atome auflösen (nicht verfügbare melden + überspringen)
#   2. Probelauf (--pretend); bei Bedarf autounmask-Änderungen schreiben + etc-update
#   3. Sammel-emerge; was danach fehlt, einzeln nachinstallieren; Fehlschläge sammeln
emerge_pkgs() {
    local sfx="" spec a todo=() rc
    if [[ ${1:-} == --optional ]]; then sfx=" (optional)"; shift; fi
    for spec in "$@"; do
        if a=$(resolve_spec "$spec"); then
            if installed "$a"; then PLAN_HAVE+=("$a")
            else todo+=("$a"); PLAN_NEW+=("$a"); ensure_keyword "$a"; fi
        else
            warn "nicht verfügbar, übersprungen: ${spec//|/ oder }"
            SKIPPED+=("${spec//|/ oder }$sfx")
        fi
    done
    ((${#todo[@]})) || return 0
    if [[ $DRY_RUN -eq 1 ]]; then info "würde installieren: ${todo[*]}"; return 0; fi

    info "Probelauf: ${todo[*]}"
    rc=0
    $SUDO "${EMERGE_BASE[@]}" --pretend --verbose --noreplace --autounmask=y --autounmask-use=y \
        --autounmask-license=y "${todo[@]}" >>"$LOG" 2>&1 || rc=$?
    if [[ $rc -ne 0 ]]; then
        info "Probelauf meldet nötige Änderungen – übernehme autounmask (USE/Keywords/Lizenzen)"
        $SUDO "${EMERGE_BASE[@]}" "${AUTOUNMASK_WRITE[@]}" "${todo[@]}" >>"$LOG" 2>&1 || true
        $SUDO etc-update --automode -5 /etc/portage >>"$LOG" 2>&1 || true
    fi

    $SUDO "${EMERGE_BASE[@]}" "${EMERGE_OPTS[@]}" "${todo[@]}" || warn "Sammel-emerge mit Fehlern – prüfe Pakete einzeln"
    for a in "${todo[@]}"; do
        installed "$a" && continue
        info "einzeln: $a"
        $SUDO "${EMERGE_BASE[@]}" "${AUTOUNMASK_WRITE[@]}" "$a" >>"$LOG" 2>&1 || true
        $SUDO etc-update --automode -5 /etc/portage >>"$LOG" 2>&1 || true
        $SUDO "${EMERGE_BASE[@]}" "${EMERGE_OPTS[@]}" "$a" || true
        if installed "$a"; then ok "$a"
        else warn "fehlgeschlagen: $a"; FAILED+=("$a$sfx"); fi
    done
    return 0
}

bashrc_block() { # bashrc_block <name> <inhalt>  – Block mit Markern in ~/.bashrc (ersetzt alten)
    local begin="# >>> gentoo-rice $1 >>>" end="# <<< gentoo-rice $1 <<<" f="$HOME/.bashrc"
    touch "$f"
    if grep -qF "$begin" "$f"; then sed -i "/$begin/,/$end/d" "$f"; fi
    printf '%s\n%s\n%s\n' "$begin" "$2" "$end" >> "$f"
}

print_problems() { # Übersprungene und fehlgeschlagene Pakete auflisten
    local s
    if ((${#SKIPPED[@]})); then
        printf '\n%sÜbersprungen (nicht verfügbar):%s\n' "$Y$B" "$N"
        for s in "${SKIPPED[@]}"; do printf '  %s!%s %s\n' "$Y" "$N" "$s"; done
    fi
    if ((${#FAILED[@]})); then
        printf '\n%sFehlgeschlagen:%s\n' "$R$B" "$N"
        for s in "${FAILED[@]}"; do printf '  %s✘%s %s\n' "$R" "$N" "$s"; done
        printf '  %sDetails im Log: %s%s\n' "$D" "$LOG" "$N"
    fi
    return 0
}

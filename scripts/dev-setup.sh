#!/usr/bin/env bash
# Gentoo-rice – Entwickler-Setup (VS Code, Claude Code, Python, Dev-Tools)
# Copyright (C) 2026 3rr0r303YT – GPL-3.0-or-later
# Aufruf: ./scripts/dev-setup.sh   oder   ./install.sh --dev
set -Eeuo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ── Ausgabe ────────────────────────────────────────────────
if [[ -t 1 ]]; then
    B=$'\e[1m'; D=$'\e[2m'; R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; C=$'\e[36m'; N=$'\e[0m'
else
    B=; D=; R=; G=; Y=; C=; N=
fi
TOTAL=8; STEP=0; CURRENT="Start"
SKIPPED=()
step() { STEP=$((STEP + 1)); CURRENT="$*"; printf '\n%s[dev %d/%d]%s %s%s%s\n' "$C$B" "$STEP" "$TOTAL" "$N" "$B" "$*" "$N"; }
info() { printf '  %s•%s %s\n' "$D" "$N" "$*"; }
ok()   { printf '  %s✔%s %s\n' "$G" "$N" "$*"; }
warn() { printf '  %s!%s %s\n' "$Y" "$N" "$*"; }
die()  { printf '\n%s✘ Fehler:%s %s\n' "$R$B" "$N" "$*" >&2; exit 1; }
trap 'rc=$?; printf "\n%s✘ Abbruch in Dev-Schritt %d (%s), Befehl: %s (Exit %d)%s\n" "$R$B" "$STEP" "$CURRENT" "$BASH_COMMAND" "$rc" "$N" >&2; exit $rc' ERR

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
KW_FILE=/etc/portage/package.accept_keywords/gentoo-rice-dev
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

printf '%s\n' "${B}Gentoo-rice${N} ${D}– Entwickler-Setup für $(id -un)${N}"

# ── 1. Portage ─────────────────────────────────────────────
step "Portage: Lizenzen, Keywords, USE-Flags"
for d in package.use package.accept_keywords package.license; do as_dir "$d"; done
write_root /etc/portage/package.license/gentoo-rice-dev <<'EOF'
# Gentoo-rice Dev
app-editors/vscode Microsoft-vscode
EOF
write_root /etc/portage/package.use/gentoo-rice-dev <<'EOF'
# Gentoo-rice Dev
net-libs/nodejs npm
dev-lang/python ensurepip sqlite
dev-vcs/git curl
EOF
$SUDO touch "$KW_FILE"
ok "Portage konfiguriert"

# ── 2. Dev-Tools ───────────────────────────────────────────
step "Dev-Tools"
emerge_pkgs \
    dev-vcs/git dev-util/github-cli net-misc/curl net-misc/wget \
    net-libs/nodejs sys-devel/gcc "llvm-core/clang|sys-devel/clang" \
    "dev-build/cmake|dev-util/cmake" "dev-build/make|sys-devel/make" \
    sys-apps/ripgrep sys-apps/fd app-misc/jq \
    sys-process/htop sys-process/btop app-editors/neovim
ok "Dev-Tools installiert"

# ── 3. Python ──────────────────────────────────────────────
step "Python, pip, pipx, venv"
emerge_pkgs dev-lang/python dev-python/pip dev-python/pipx
command -v python3 >/dev/null || die "python3 nicht gefunden."
if python3 -m venv --help >/dev/null 2>&1; then ok "venv verfügbar ($(python3 --version))"
else warn "python3 -m venv nicht nutzbar (USE=ensurepip prüfen)"; fi
if command -v pipx >/dev/null; then
    pipx ensurepath >/dev/null 2>&1 || true
    ok "pipx ensurepath"
fi

# ── 4. Claude Code ─────────────────────────────────────────
step "Claude Code (nativer Installer)"
if [[ -x $HOME/.local/bin/claude ]] || command -v claude >/dev/null; then
    ok "Claude Code bereits installiert (aktualisiert sich selbst)"
else
    command -v curl >/dev/null || die "curl fehlt – Claude Code kann nicht geladen werden."
    curl -fsSL https://claude.ai/install.sh | bash || die "Claude-Code-Installer fehlgeschlagen."
fi
if ! grep -qE '\.local/bin' "$HOME/.bashrc" 2>/dev/null || grep -qF '# >>> gentoo-rice path >>>' "$HOME/.bashrc"; then
    bashrc_block path 'case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac'
    info "PATH in ~/.bashrc ergänzt"
fi
hash -r
claude --version >/dev/null 2>&1 || die "\"claude --version\" schlägt fehl – Installation prüfen (~/.local/bin/claude)."
ok "claude $(claude --version 2>/dev/null)"

# ── 5. VS Code ─────────────────────────────────────────────
step "VS Code"
emerge_pkgs app-editors/vscode
command -v code >/dev/null || die "VS Code (code) nicht verfügbar – app-editors/vscode konnte nicht installiert werden."
ok "VS Code $(code --version 2>/dev/null | sed -n 1p)"

# ── 6. Extensions ──────────────────────────────────────────
step "VS-Code-Extensions"
EXTS=(
    anthropic.claude-code
    ms-python.python
    ms-python.vscode-pylance
    eamodio.gitlens
    usernamehw.errorlens
    github.github-vscode-theme
)
have=$(code --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]')
for e in "${EXTS[@]}"; do
    if grep -qxF "${e,,}" <<<"$have"; then ok "$e"
    elif code --install-extension "$e" --force >/dev/null 2>&1; then ok "$e installiert"
    else warn "Extension fehlgeschlagen: $e"; SKIPPED+=("vscode:$e"); fi
done

# ── 7. VS-Code-Config ──────────────────────────────────────
step "VS Code: settings.json & Wayland-Flags"
VS_USER="$HOME/.config/Code/User"; mkdir -p "$VS_USER"
SET="$VS_USER/settings.json"
if [[ -f $SET ]] && grep -qF '"// gentoo-rice"' "$SET"; then
    ok "settings.json vorhanden (Rice-Version, wird nicht überschrieben)"
else
    if [[ -e $SET ]]; then
        cp "$SET" "$SET.bak-$(date +%Y-%m-%d_%H-%M-%S)"; info "Backup: $SET.bak-…"
    fi
    cp "$REPO/vscode/settings.json" "$SET"
    ok "settings.json im Rice-Look angelegt"
fi
for f in code-flags.conf electron-flags.conf; do
    if ! cmp -s "$REPO/vscode/code-flags.conf" "$HOME/.config/$f"; then
        [[ -e $HOME/.config/$f ]] && cp "$HOME/.config/$f" "$HOME/.config/$f.bak-$(date +%Y-%m-%d_%H-%M-%S)"
        cp "$REPO/vscode/code-flags.conf" "$HOME/.config/$f"
    fi
done
ok "~/.config/code-flags.conf (--ozone-platform=wayland)"

# ── 8. Git ─────────────────────────────────────────────────
step "Git-Basis-Konfiguration"
gname=$(git config --global user.name || true)
gmail=$(git config --global user.email || true)
if [[ -z $gname || -z $gmail ]]; then
    if [[ -t 0 ]]; then
        if [[ -z $gname ]]; then read -r -p "  Git-Name: " gname || true; fi
        if [[ -n $gname ]]; then git config --global user.name "$gname"; fi
        if [[ -z $gmail ]]; then read -r -p "  Git-E-Mail: " gmail || true; fi
        if [[ -n $gmail ]]; then git config --global user.email "$gmail"; fi
    else
        warn "Kein Terminal – später setzen: git config --global user.name/user.email"
    fi
fi
git config --global init.defaultBranch >/dev/null || git config --global init.defaultBranch main
git config --global pull.rebase >/dev/null || git config --global pull.rebase false
git config --global core.editor >/dev/null || git config --global core.editor nvim
ok "git: ${gname:-<kein Name>} <${gmail:-keine Mail}>"

# ── Übersicht ──────────────────────────────────────────────
ver() { # ver <label> <befehl…>
    local v
    if v=$("${@:2}" 2>/dev/null) && v=${v%%$'\n'*} && [[ -n $v ]]; then
        printf '  %s✔%s %-10s %s\n' "$G" "$N" "$1" "$v"
    else
        printf '  %s–%s %-10s %snicht installiert%s\n' "$Y" "$N" "$1" "$D" "$N"
    fi
}
printf '\n%s╭─ Installierte Versionen ──────────────────────╮%s\n' "$B" "$N"
ver "VS Code"  code --version
ver "Claude"   claude --version
ver "Python"   python3 --version
ver "pip"      python3 -m pip --version
ver "pipx"     pipx --version
ver "git"      git --version
ver "gh"       gh --version
ver "node"     node --version
ver "npm"      npm --version
ver "gcc"      gcc --version
ver "clang"    clang --version
ver "cmake"    cmake --version
ver "make"     make --version
ver "ripgrep"  rg --version
ver "fd"       fd --version
ver "jq"       jq --version
ver "htop"     htop --version
ver "btop"     btop --version
ver "neovim"   nvim --version
ver "curl"     curl --version
ver "wget"     wget --version
printf '%s╰───────────────────────────────────────────────╯%s\n' "$B" "$N"
if ((${#SKIPPED[@]})); then
    printf '\n%sÜbersprungen:%s %s\n' "$Y$B" "$N" "${SKIPPED[*]}"
fi
printf '\n%sNeues Terminal öffnen (oder: source ~/.bashrc), damit PATH greift.%s\n\n' "$D" "$N"
exit 0

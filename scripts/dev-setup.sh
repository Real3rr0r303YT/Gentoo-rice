#!/usr/bin/env bash
# Gentoo-rice – Entwickler-Setup (VS Code, Claude Code, Python, Dev-Tools)
# Copyright (C) 2026 3rr0r303YT – GPL-3.0-or-later
# Aufruf: ./scripts/dev-setup.sh   oder   ./install.sh --dev
set -Eeuo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

TOTAL=8 STEP_LABEL=dev KW_FILE=/etc/portage/package.accept_keywords/gentoo-rice-dev
# shellcheck source=scripts/lib.sh
source "$REPO/scripts/lib.sh"

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
emerge_pkgs dev-lang/python dev-python/pip "dev-python/pipx|app-misc/pipx"
"$REPO/scripts/ensure-pipx.sh" || warn "pipx konnte nicht eingerichtet werden"
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
    # shellcheck disable=SC2016  # $PATH/$HOME sollen erst in ~/.bashrc expandieren
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
    else warn "Extension fehlgeschlagen: $e"; FAILED+=("VS-Code-Extension $e"); fi
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
ok "$HOME/.config/code-flags.conf (--ozone-platform=wayland)"

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
print_problems
printf '\n%sNeues Terminal öffnen (oder: source ~/.bashrc), damit PATH greift.%s\n\n' "$D" "$N"
exit 0

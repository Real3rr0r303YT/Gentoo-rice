#!/usr/bin/env bash
# Gentoo-rice – Claude Code über den offiziellen nativen Installer einrichten
# Mehrfach ausführbar: vorhandene Installation wird nur geprüft (Claude Code aktualisiert sich selbst).
set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"

BEGIN="# >>> gentoo-rice path >>>"
END="# <<< gentoo-rice path <<<"

if [[ -x $HOME/.local/bin/claude ]] || command -v claude >/dev/null; then
    echo "Claude Code bereits installiert"
else
    command -v curl >/dev/null || { echo "curl fehlt (net-misc/curl)" >&2; exit 1; }
    curl -fsSL https://claude.ai/install.sh | bash || { echo "Claude-Code-Installer fehlgeschlagen" >&2; exit 1; }
fi

# ~/.local/bin in den PATH (nur falls noch nicht eingetragen)
touch "$HOME/.bashrc"
if ! grep -qE '\.local/bin' "$HOME/.bashrc" || grep -qF "$BEGIN" "$HOME/.bashrc"; then
    if grep -qF "$BEGIN" "$HOME/.bashrc"; then sed -i "/$BEGIN/,/$END/d" "$HOME/.bashrc"; fi
    # shellcheck disable=SC2016  # $PATH/$HOME sollen erst in ~/.bashrc expandieren
    printf '%s\n%s\n%s\n' "$BEGIN" 'case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac' "$END" >> "$HOME/.bashrc"
    echo "PATH in ~/.bashrc ergänzt"
fi

hash -r
if v=$(claude --version 2>/dev/null); then
    echo "claude $v"
else
    echo "\"claude --version\" schlägt fehl – Installation prüfen (~/.local/bin/claude)" >&2
    exit 1
fi

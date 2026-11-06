#!/usr/bin/env bash
# Gentoo-rice – stellt pipx bereit, auch wenn kein Gentoo-Paket verfügbar ist
#   1. vorhandenes pipx
#   2. eigenes venv unter ~/.local/share/gentoo-rice-pipx (PEP-668-sicher)
#   3. python3 -m pip install --user pipx (ggf. mit --break-system-packages)
set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"
command -v pipx >/dev/null && exit 0

PY=$(command -v python3 || command -v python) || { echo "python3 fehlt" >&2; exit 1; }
VENV="$HOME/.local/share/gentoo-rice-pipx"
mkdir -p "$HOME/.local/bin"

if "$PY" -m venv "$VENV" && "$VENV/bin/python" -m pip install -q --upgrade pip pipx; then
    ln -sfn "$VENV/bin/pipx" "$HOME/.local/bin/pipx"
    echo "pipx im venv installiert: $VENV"
    exit 0
fi
rm -rf "$VENV"

if "$PY" -m pip install -q --user pipx 2>/dev/null ||
   "$PY" -m pip install -q --user --break-system-packages pipx; then
    command -v pipx >/dev/null && { echo "pipx per pip --user installiert"; exit 0; }
fi
echo "pipx konnte nicht installiert werden" >&2
exit 1

#!/usr/bin/env bash
# Gentoo-rice – linux-wallpaperengine (Almamu) bauen und einrichten
# Copyright (C) 2026 3rr0r303YT – GPL-3.0-or-later
# Aufruf: ./scripts/wallpaperengine.sh   oder   ./install.sh --we
set -Eeuo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOTAL=5 STEP_LABEL=we KW_FILE=/etc/portage/package.accept_keywords/gentoo-rice-we
# shellcheck source=scripts/lib.sh
source "$REPO/scripts/lib.sh"
# shellcheck source=scripts/we-lib.sh
source "$REPO/scripts/we-lib.sh"

UPSTREAM="https://github.com/Almamu/linux-wallpaperengine.git"
SRC="$HOME/.local/src/linux-wallpaperengine"
OPT="$HOME/.local/opt/linux-wallpaperengine"

printf '%s\n' "${B}Gentoo-rice${N} ${D}– Wallpaper Engine (linux-wallpaperengine) für $(id -un)${N}"

# ── 1. Abhängigkeiten ──────────────────────────────────────
step "Abhängigkeiten"
as_dir package.accept_keywords
$SUDO touch "$KW_FILE"
emerge_pkgs \
    "dev-build/cmake|dev-util/cmake" dev-vcs/git media-libs/libsdl2 media-libs/glew \
    media-libs/glfw media-libs/glm media-video/mpv media-video/ffmpeg app-arch/lz4 \
    "virtual/zlib|sys-libs/zlib" media-libs/freeglut x11-libs/libXrandr \
    "media-libs/libpulse|media-sound/pulseaudio" dev-libs/wayland dev-libs/wayland-protocols \
    sci-libs/fftw net-misc/socat virtual/opengl
ok "Abhängigkeiten geprüft"

# ── 2. Quellcode ───────────────────────────────────────────
step "Quellcode (${SRC/#$HOME/\~})"
if [[ -d $SRC/.git ]]; then
    git -C "$SRC" pull --ff-only || die "git pull in $SRC fehlgeschlagen (lokale Änderungen?)."
    git -C "$SRC" submodule update --init --recursive || die "Submodule konnten nicht aktualisiert werden."
    ok "aktualisiert ($(git -C "$SRC" rev-parse --short HEAD))"
else
    mkdir -p "$(dirname "$SRC")"
    git clone --recurse-submodules "$UPSTREAM" "$SRC" || die "Klonen von $UPSTREAM fehlgeschlagen."
    ok "geklont ($(git -C "$SRC" rev-parse --short HEAD))"
fi

# ── 3. Bauen ───────────────────────────────────────────────
step "Bauen (cmake, -j$(nproc))"
cmake -S "$SRC" -B "$SRC/build" -DCMAKE_BUILD_TYPE=Release >/dev/null ||
    die "cmake-Konfiguration fehlgeschlagen – fehlende Abhängigkeiten? Details: cmake -S $SRC -B $SRC/build"
cmake --build "$SRC/build" -j"$(nproc)" || die "Build fehlgeschlagen (Details oben)."
ok "gebaut"

# ── 4. Installieren ────────────────────────────────────────
step "Installieren nach ~/.local"
bin=""
for c in "$SRC/build/output/linux-wallpaperengine" "$SRC/build/linux-wallpaperengine"; do
    [[ -x $c && -f $c ]] && { bin=$c; break; }
done
[[ -n $bin ]] || bin=$(find "$SRC/build" -maxdepth 3 -type f -name linux-wallpaperengine -perm -u+x | head -n1)
[[ -n $bin ]] || die "Binary linux-wallpaperengine nach dem Build nicht gefunden."
outdir=$(dirname "$bin")
rm -rf "$OPT.new"; mkdir -p "$OPT.new"
if [[ $outdir == "$SRC/build" ]]; then
    # Build-Wurzel: nur Laufzeitdateien kopieren
    cp -a "$bin" "$OPT.new/"
    for f in "$outdir"/*.so* "$outdir"/*.pak "$outdir"/*.dat "$outdir"/*.bin "$outdir"/*.json \
             "$outdir"/assets "$outdir"/locales "$outdir"/shaders; do
        if [[ -e $f ]]; then cp -a "$f" "$OPT.new/"; fi
    done
else
    cp -a "$outdir"/. "$OPT.new/"
fi
rm -rf "$OPT"; mv "$OPT.new" "$OPT"
mkdir -p "$HOME/.local/bin"
cat > "$WE_BIN" <<EOF
#!/bin/sh
# Gentoo-rice – Starter für linux-wallpaperengine
cd "$OPT" && exec "$OPT/linux-wallpaperengine" "\$@"
EOF
chmod +x "$WE_BIN"
ok "$WE_BIN → ${OPT/#$HOME/\~}"

# ── 5. Konfiguration & Steam ───────────────────────────────
step "Konfiguration & Steam-Pfade"
mkdir -p "$(dirname "$WE_CONF")"
if [[ -f $WE_CONF ]]; then ok "Config vorhanden: ${WE_CONF/#$HOME/\~}"
else cp "$REPO/config/wallpaperengine.conf" "$WE_CONF"; ok "Config angelegt: ${WE_CONF/#$HOME/\~}"; fi
we_load_config
libs=$(we_libraries)
if [[ -n $libs ]]; then
    while IFS= read -r l; do info "Steam-Bibliothek: ${l/#$HOME/\~}"; done <<<"$libs"
else
    warn "Keine Steam-Installation gefunden (Flatpak: ~/.var/app/com.valvesoftware.Steam, nativ: ~/.local/share/Steam)"
fi
if assets=$(we_assets_dir); then ok "Assets: ${assets/#$HOME/\~}"
else warn "Wallpaper-Engine-Assets nicht gefunden"; fi
n=$(we_list | awk -F'\t' '$2=="scene"||$2=="video"||$2=="web"' | wc -l)
ok "$n Workshop-Wallpaper gefunden"

printf '\n%s╭─ Wallpaper Engine ─────────────────────────────╮%s\n' "$B" "$N"
printf '  %s!%s Wallpaper Engine muss in Steam gekauft und installiert sein –\n' "$Y" "$N"
printf '    die Assets und Workshop-Wallpaper kommen von dort (App-ID %s).\n' "$WE_APPID"
printf '  • Wallpaper im Workshop abonnieren, dann Super+W → Einträge mit „WE“\n'
printf '  • Direkt: ~/.local/share/gentoo-rice/scripts/we-set.sh <Workshop-ID>\n'
printf '  • Einstellungen: %s\n' "${WE_CONF/#$HOME/\~}"
printf '%s╰────────────────────────────────────────────────╯%s\n' "$B" "$N"
print_problems
exit 0

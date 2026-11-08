#!/usr/bin/env bash
# Gentoo-rice – GRUB-Bootmenü: Theme (Klötzchen oder blau), sichtbares Menü mit Auswahlzeit + Windows-Eintrag (os-prober)
# Copyright (C) 2026 3rr0r303YT – GPL-3.0-or-later
#
# Nutzung: ./scripts/grub-setup.sh [--timeout SEKUNDEN] [--theme blocks|blue] [--no-theme]
#          Standard: 5 s, Theme blocks (Klötzchen-Look)
#          ./scripts/grub-setup.sh --restore               (Original von /etc/default/grub zurück)
set -Eeuo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TIMEOUT=5 RESTORE=0 THEME=1 THEME_NAME=gentoo-rice-blocks
while (($#)); do
    case $1 in
        --timeout) TIMEOUT=${2:-}; shift ;;
        --timeout=*) TIMEOUT=${1#*=} ;;
        --restore) RESTORE=1 ;;
        --no-theme) THEME=0 ;;
        --theme|--theme=*)
            if [[ $1 == --theme ]]; then t=${2:-}; shift; else t=${1#*=}; fi
            case $t in
                blocks|minecraft) THEME_NAME=gentoo-rice-blocks ;;
                blue|blau) THEME_NAME=gentoo-rice ;;
                *) printf 'Unbekanntes Theme: %s (blocks|blue)\n' "$t" >&2; exit 1 ;;
            esac ;;
        -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
        *) printf 'Unbekannte Option: %s\n' "$1" >&2; exit 1 ;;
    esac
    shift
done
[[ $TIMEOUT =~ ^[0-9]+$ ]] || { echo "--timeout braucht eine Zahl (Sekunden)" >&2; exit 1; }

TOTAL=$((4 + THEME)) STEP_LABEL=grub
# shellcheck source=scripts/lib.sh
source "$REPO/scripts/lib.sh"

CFG=/etc/default/grub
ORIG=/etc/default/grub.gentoo-rice.orig
THEME_DIR="" THEME_FONT=""
# Kernel-Update-Hook: Menü nach jedem neuen Kernel wieder englisch + kurz ("Gentoo")
HOOK=/etc/kernel/postinst.d/99-gentoo-rice-grub
SHORTEN='/^[[:space:]]*(menuentry|submenu) /s| GNU/Linux||g'

# Ausgabedatei von grub-mkconfig finden (Gentoo: /boot/grub/grub.cfg)
grub_cfg() {
    local d
    for d in /boot/grub /boot/grub2 /efi/grub /boot/efi/grub; do
        if $SUDO test -d "$d"; then echo "$d/grub.cfg"; return 0; fi
    done
    return 1
}
mkconfig() {
    local out
    out=$(grub_cfg) || die "Kein GRUB-Verzeichnis gefunden (/boot/grub). Ist /boot gemountet? (sudo mount /boot)"
    command -v grub-mkconfig >/dev/null || die "grub-mkconfig fehlt (sys-boot/grub)."
    info "grub-mkconfig -o $out"
    local tmp
    tmp=$(mktemp)
    # LANG=C: Menü und GRUB-Meldungen auf Englisch
    if ! $SUDO env LANG=C LC_ALL=C LANGUAGE= grub-mkconfig -o "$out" >"$tmp" 2>&1; then
        cat "$tmp" >> "$LOG"; rm -f "$tmp"
        die "grub-mkconfig fehlgeschlagen – Details im Log. Altes Bootmenü bleibt unverändert."
    fi
    cat "$tmp" >> "$LOG"
    grep -iE 'found|warn' "$tmp" | sed 's/^/  · /' || true
    rm -f "$tmp"
    if ((!RESTORE)); then
        # nur der Name des Betriebssystems: "Gentoo" statt "Gentoo GNU/Linux"
        $SUDO sed -i -E "$SHORTEN" "$out"
    fi
    if $SUDO grep -qiE "menuentry ['\"]?Windows" "$out"; then ok "Windows-Eintrag im Bootmenü"
    else info "Kein Windows gefunden (normal, wenn nur Gentoo installiert ist)"; fi
    ok "Bootmenü geschrieben: $out"
}

# slice9 <farbe> <präfix> <radius> <ordner> – abgerundete Box als 9 Einzelbilder (GRUB-Pixmap-Stil)
slice9() {
    local c=$1 p=$2 r=$3 d=$4 x y i=0 size
    local names=(nw n ne w c e sw s se)
    size=$((r * 3))
    magick -size "${size}x${size}" xc:none -fill "$c" \
        -draw "roundrectangle 0,0 $((size - 1)),$((size - 1)) $r,$r" "PNG32:$d/$p-full.png"
    for y in 0 1 2; do
        for x in 0 1 2; do
            magick "$d/$p-full.png" -crop "${r}x${r}+$((x * r))+$((y * r))" +repage "PNG32:$d/${p}_${names[i]}.png"
            i=$((i + 1))
        done
    done
    rm -f "$d/$p-full.png"
}

# grub-mkfont (USE=truetype) für eigene Schriften im Theme
ensure_mkfont() {
    command -v grub-mkfont >/dev/null && return 0
    info "grub-mkfont fehlt → sys-boot/grub mit USE=truetype neu bauen"
    as_dir package.use
    add_line_root /etc/portage/package.use/gentoo-rice-grub "sys-boot/grub fonts truetype"
    $SUDO "${EMERGE_BASE[@]}" --oneshot --newuse --getbinpkg --binpkg-respect-use=y --quiet-build=y sys-boot/grub >>"$LOG" 2>&1 || true
    command -v grub-mkfont >/dev/null
}

install_theme() {
    local cfg tmp f font=""
    cfg=$(grub_cfg) || { warn "Kein GRUB-Verzeichnis (/boot gemountet?) – Theme übersprungen"; return 1; }
    THEME_DIR="$(dirname "$cfg")/themes/$THEME_NAME"
    tmp=$(mktemp -d)
    cp -a "$REPO/grub/$THEME_NAME"/. "$tmp"/

    if [[ $THEME_NAME == gentoo-rice ]]; then
        theme_blue "$tmp" || { rm -rf "$tmp"; return 1; }
        if [[ -f $tmp/rice-16.pf2 ]]; then font=rice-16.pf2; fi
    else
        # Klötzchen-Look: fertige Pixelbilder aus dem Repo + Unifont (Pixel-Schrift von GRUB)
        for f in /usr/share/grub/unicode.pf2 "$(dirname "$cfg")/fonts/unicode.pf2"; do
            if $SUDO test -s "$f"; then $SUDO cat "$f" > "$tmp/unifont.pf2"; break; fi
        done
        if [[ ! -s $tmp/unifont.pf2 ]] && ensure_mkfont && [[ -s /usr/share/grub/unicode.pf2 ]]; then
            cp /usr/share/grub/unicode.pf2 "$tmp/unifont.pf2"
        fi
        if [[ -s $tmp/unifont.pf2 ]]; then font=unifont.pf2; ok "Schrift: Unifont (Pixel)"
        else rm -f "$tmp/unifont.pf2"; warn "unicode.pf2 fehlt (sys-boot/grub USE=fonts) – Theme evtl. ohne Text"; fi
        ok "Klötzchen-Look: Erde, Stein-Knöpfe, Titel"
    fi

    $SUDO rm -rf "$THEME_DIR"
    $SUDO mkdir -p "$THEME_DIR"
    $SUDO cp -a "$tmp"/. "$THEME_DIR"/
    $SUDO chmod -R a+rX "$THEME_DIR"
    rm -rf "$tmp"
    THEME_FONT=${font:+$THEME_DIR/$font}
    ok "Theme installiert: $THEME_DIR"
}

theme_blue() { # theme_blue <ordner> – Bilder + Schriften für das blaue Theme erzeugen
    local tmp=$1 bg="" f fr fb sz bold=()
    command -v magick >/dev/null || { warn "ImageMagick (magick) fehlt – Theme übersprungen"; return 1; }

    # Hintergrund: Wallpaper weichgezeichnet + blauer Verlauf (sonst nur Verlauf)
    for f in /var/lib/gentoo-rice/sddm/background.jpg "$HOME/.cache/rice/current.png"; do
        if [[ -s $f ]]; then bg=$f; break; fi
    done
    if [[ -n $bg ]] && magick "$bg" -resize 1920x1080^ -gravity center -extent 1920x1080 \
        -resize 25% -blur 0x8 -resize 400% \
        \( -size 1920x1080 gradient:"rgba(18,51,128,0.72)-rgba(4,9,26,0.94)" \) -composite \
        -alpha off "PNG24:$tmp/background.png" 2>>"$LOG"; then
        ok "Hintergrund aus dem Wallpaper"
    else
        magick -size 1920x1080 gradient:"#123380-#040a1a" "PNG24:$tmp/background.png"
        ok "Hintergrund: blauer Verlauf"
    fi
    slice9 "rgba(15,23,42,0.72)" menu 18 "$tmp"
    slice9 "#3b82f6" select 12 "$tmp"

    # Schriften (JetBrains Mono → GRUB-pf2), Namen: "Rice Regular <n>" / "Rice Bold <n>"
    if ensure_mkfont; then
        fr=$(fc-match -f '%{file}' 'JetBrains Mono:style=Regular' 2>/dev/null || true)
        fb=$(fc-match -f '%{file}' 'JetBrains Mono:style=Bold' 2>/dev/null || true)
        if [[ ! ${fb,,} =~ bold ]]; then fb=$fr; bold=(-b); fi
        if [[ -n $fr ]]; then
            for sz in 14 16 18; do grub-mkfont -n Rice -s "$sz" -o "$tmp/rice-$sz.pf2" "$fr" >>"$LOG" 2>&1 || true; done
            for sz in 16 18 32; do grub-mkfont -n Rice "${bold[@]}" -s "$sz" -o "$tmp/rice-bold-$sz.pf2" "$fb" >>"$LOG" 2>&1 || true; done
        fi
    fi
    if [[ -f $tmp/rice-16.pf2 ]]; then ok "Schrift: $(basename "$fr")"
    else warn "Keine eigene Schrift (grub-mkfont) – GRUB nimmt seine Standardschrift"; fi
}

[[ -f $CFG ]] || die "$CFG fehlt – GRUB (sys-boot/grub) ist nicht installiert oder nicht der Bootloader."

if ((RESTORE)); then
    step "Original wiederherstellen"
    [[ -f $ORIG ]] || die "Kein Backup ($ORIG) vorhanden."
    $SUDO cp -a "$ORIG" "$CFG"
    ok "$CFG aus $ORIG wiederhergestellt"
    if [[ -f $HOOK ]]; then $SUDO rm -f "$HOOK"; ok "Kernel-Hook entfernt: $HOOK"; fi
    step "Bootmenü neu erzeugen"
    mkconfig
    exit 0
fi

printf '%s\n' "${B}Gentoo-rice${N} ${D}– GRUB: $TIMEOUT s Auswahlzeit, Windows im Menü${N}"

# ── 1. Backup ─────────────────────────────────────────────
step "Backup von $CFG"
if [[ -f $ORIG ]]; then
    info "Original-Backup existiert bereits: $ORIG"
else
    $SUDO cp -a "$CFG" "$ORIG"
    ok "gesichert: $ORIG"
fi
$SUDO cp -a "$CFG" "$CFG.bak-$(date +%Y-%m-%d_%H-%M-%S)"

# ── 2. os-prober (Windows erkennen) ───────────────────────
step "os-prober für den Windows-Eintrag"
emerge_pkgs sys-boot/os-prober
if command -v os-prober >/dev/null; then ok "os-prober vorhanden"; else warn "os-prober fehlt – Windows erscheint evtl. nicht im Menü"; fi

# ── 3. Theme ──────────────────────────────────────────────
if ((THEME)); then
    step "GRUB-Theme ($THEME_NAME)"
    install_theme || THEME_DIR=""
fi

# ── 4. /etc/default/grub anpassen ─────────────────────────
step "Einstellungen"
set_kv() { # set_kv <SCHLÜSSEL> <WERT> – vorhandene (auch auskommentierte) Zeile ersetzen, sonst anhängen
    local k=$1 v=$2
    if $SUDO grep -qE "^[#[:space:]]*$k=" "$CFG"; then
        $SUDO sed -i -E "s|^[#[:space:]]*$k=.*|$k=$v|" "$CFG"
    else
        echo "$k=$v" | $SUDO tee -a "$CFG" >/dev/null
    fi
    info "$k=$v"
}
set_kv GRUB_TIMEOUT "$TIMEOUT"
set_kv GRUB_TIMEOUT_STYLE menu
set_kv GRUB_DISABLE_OS_PROBER false
KEYS=(GRUB_TIMEOUT GRUB_TIMEOUT_STYLE GRUB_DISABLE_OS_PROBER)
if [[ -n $THEME_DIR ]]; then
    # GRUB_TERMINAL=console würde das Theme abschalten
    $SUDO sed -i -E 's|^GRUB_TERMINAL=|#GRUB_TERMINAL=|' "$CFG"
    set_kv GRUB_TERMINAL_OUTPUT gfxterm
    set_kv GRUB_GFXMODE auto
    set_kv GRUB_GFXPAYLOAD_LINUX keep
    set_kv GRUB_THEME "$THEME_DIR/theme.txt"
    KEYS+=(GRUB_TERMINAL_OUTPUT GRUB_GFXMODE GRUB_GFXPAYLOAD_LINUX GRUB_THEME)
    if [[ -n $THEME_FONT ]]; then set_kv GRUB_FONT "$THEME_FONT"; KEYS+=(GRUB_FONT); fi
fi
# Nur eine Zeile pro Schlüssel behalten (falls doppelt vorhanden)
for k in "${KEYS[@]}"; do
    n=$($SUDO grep -cE "^$k=" "$CFG" || true)
    if ((n > 1)); then $SUDO sed -i -E "0,/^$k=/! { /^$k=/d }" "$CFG"; fi
done
ok "$CFG angepasst"

# Kernel-Updates (installkernel) erzeugen das Menü neu → danach wieder englisch + kurz
write_root "$HOOK" <<HOOK_EOF
#!/bin/sh
# Gentoo-rice (scripts/grub-setup.sh): GRUB-Menü nach Kernel-Updates englisch und kurz ("Gentoo")
for d in /boot/grub /boot/grub2 /efi/grub /boot/efi/grub; do
    if [ -f "\$d/grub.cfg" ]; then
        LANG=C LC_ALL=C LANGUAGE= grub-mkconfig -o "\$d/grub.cfg" >/dev/null 2>&1 || exit 0
        sed -i -E '$SHORTEN' "\$d/grub.cfg"
        break
    fi
done
exit 0
HOOK_EOF
$SUDO chmod 0755 "$HOOK"

# ── 5. Bootmenü erzeugen ──────────────────────────────────
step "Bootmenü neu erzeugen"
mkconfig

print_problems
printf '\n%sFertig:%s Beim nächsten Start zeigt GRUB das Menü %s Sekunden lang (Pfeiltasten + Enter).\n' "$G$B" "$N" "$TIMEOUT"
printf '%sRückgängig:%s ./scripts/grub-setup.sh --restore\n' "$D" "$N"

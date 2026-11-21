#!/usr/bin/env bash
# Darkroot OS – eigene Live-ISO bauen: offizielle Gentoo-LiveGUI-ISO + Calamares-Installer + Gentoo-rice
# Copyright (C) 2026 3rr0r303YT – GPL-3.0-or-later
#
# Ergebnis: iso/out/darkroot-<datum>.iso
#   - Live-Desktop XFCE mit "Darkroot OS installieren" (Calamares, startet automatisch)
#   - Calamares kopiert das Live-System auf die Platte (UEFI, GRUB), legt den Benutzer an
#     und legt das Gentoo-rice bereit – es installiert sich beim ersten Login (Hyprland, Mac-Login, Apps)
#   - Konsolen-Installer als Alternative: cli-install
#
# Nutzung (auf Gentoo, als normaler Benutzer – sudo wird gefragt; braucht ~25 GB frei):
#   ./iso/build-iso.sh            bauen
#   ./iso/build-iso.sh --keep     Arbeitsordner behalten
#   ISO_NAME="Mein OS" ISO_SLUG=meinos ./iso/build-iso.sh
set -Eeuo pipefail

REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
NAME=${ISO_NAME:-Darkroot OS}
SLUG=${ISO_SLUG:-darkroot}
KEEP=0
if [[ ${1:-} == --keep ]]; then KEEP=1; fi

MIRROR=${GENTOO_MIRROR:-https://distfiles.gentoo.org}
AUTOBUILDS="$MIRROR/releases/amd64/autobuilds"
WORK="$REPO/iso/work"
OUT="$REPO/iso/out"
ISO_OUT="$OUT/$SLUG-$(date +%Y%m%d).iso"
ISO_DIR="$WORK/iso" ROOT="$WORK/root"

TOTAL=7 STEP_LABEL=iso
# shellcheck source=scripts/lib.sh
source "$REPO/scripts/lib.sh"

cleanup_mounts() {
    local m
    for m in run dev sys proc; do
        if mountpoint -q "$ROOT/$m" 2>/dev/null; then
            $SUDO umount -R "$ROOT/$m" 2>/dev/null || $SUDO umount -lR "$ROOT/$m" 2>/dev/null || true
        fi
    done
    return 0
}
trap cleanup_mounts EXIT

printf '%s\n' "${B}$NAME${N} ${D}– Live-ISO bauen (Gentoo-LiveGUI + Calamares + Gentoo-rice)${N}"
mkdir -p "$WORK" "$OUT"

# ── 1. Werkzeuge ──────────────────────────────────────────
step "Werkzeuge (xorriso, squashfs-tools, curl, ImageMagick)"
# squashfs-tools braucht xz/zstd/lz4 – die LiveGUI-ISO ist so komprimiert
as_dir package.use
echo "sys-fs/squashfs-tools lzma zstd lz4 xattr" | write_root /etc/portage/package.use/gentoo-rice-iso
emerge_pkgs dev-libs/libisoburn sys-fs/squashfs-tools net-misc/curl media-gfx/imagemagick
# Test: kleines xz-Abbild bauen (die Hilfe-Ausgabe listet die Kompressionen nicht in jeder Version)
can_xz() {
    local d; d=$(mktemp -d)
    mkdir "$d/in" && echo x > "$d/in/f"
    mksquashfs "$d/in" "$d/t.sqfs" -comp xz -noappend -quiet >/dev/null 2>&1
    local rc=$?; rm -rf "$d"; return $rc
}
if ! can_xz; then
    info "squashfs-tools ohne xz → neu bauen mit USE=\"lzma zstd lz4\""
    $SUDO "${EMERGE_BASE[@]}" --oneshot --newuse --getbinpkg --binpkg-respect-use=y --quiet-build=y sys-fs/squashfs-tools >>"$LOG" 2>&1 || true
    hash -r
fi
can_xz || die "squashfs-tools kann kein xz – sudo emerge -1 --newuse sys-fs/squashfs-tools (Details im Log)"
ok "squashfs-tools mit xz"
for t in xorriso unsquashfs mksquashfs curl sha256sum magick; do
    command -v "$t" >/dev/null || die "$t fehlt."
done
ok "alles da"

# ── 2. Offizielle LiveGUI-ISO laden + prüfen ──────────────
step "Offizielle Gentoo-LiveGUI-ISO"
latest=$(curl -fsSL "$AUTOBUILDS/latest-livegui-amd64.txt" | awk '$1 ~ /\.iso$/ {print $1; exit}') ||
    die "Konnte die aktuelle LiveGUI-Version nicht ermitteln ($AUTOBUILDS)."
[[ -n $latest ]] || die "Leere Antwort von latest-livegui-amd64.txt"
base_iso="$WORK/$(basename "$latest")"
if [[ ! -s $base_iso ]]; then
    info "lade $(basename "$latest") (ca. 3–4 GB) …"
    curl -fL --progress-bar -o "$base_iso.part" "$AUTOBUILDS/$latest" || die "Download fehlgeschlagen."
    mv "$base_iso.part" "$base_iso"
fi
if curl -fsSL -o "$base_iso.sha256" "$AUTOBUILDS/$latest.sha256" 2>/dev/null; then
    want=$(grep -oE '\b[0-9a-f]{64}\b' "$base_iso.sha256" | head -n1)
    if [[ -z $want || $want != "$(sha256sum "$base_iso" | cut -d' ' -f1)" ]]; then
        rm -f "$base_iso"; die "Prüfsumme stimmt nicht – Datei gelöscht, bitte erneut starten."
    fi
    ok "Prüfsumme ok"
else
    warn "Keine .sha256 gefunden – Prüfsumme nicht kontrolliert"
fi
ok "Basis: $(basename "$base_iso")"

# ── 3. Auspacken ──────────────────────────────────────────
step "ISO und Root-Dateisystem auspacken"
cleanup_mounts
$SUDO rm -rf "$ISO_DIR" "$ROOT"
mkdir -p "$ISO_DIR"
xorriso -osirrox on -indev "$base_iso" -extract / "$ISO_DIR" >>"$LOG" 2>&1 || die "ISO konnte nicht ausgepackt werden."
chmod -R u+w "$ISO_DIR"
SQUASH=$(find "$ISO_DIR" -maxdepth 3 \( -name '*.squashfs' -o -name 'squashfs.img' \) | head -n1)
[[ -n $SQUASH ]] || die "Kein squashfs-Abbild in der ISO gefunden."
if ! $SUDO unsquashfs -q -d "$ROOT" "$SQUASH" >>"$LOG" 2>&1; then
    tail -5 "$LOG" | sed 's/^/    /'
    die "unsquashfs fehlgeschlagen (Kompression: $(unsquashfs -s "$SQUASH" 2>/dev/null | awk '/Compression/ {print $2}'))."
fi
ok "Root-Dateisystem ausgepackt ($(basename "$SQUASH"))"

# ── 4. Pakete im Live-System: Calamares, Kernel für die Platte, GRUB ─
step "Calamares, Kernel und GRUB ins Live-System (chroot, Binärpakete)"
$SUDO cp -L /etc/resolv.conf "$ROOT/etc/resolv.conf"
$SUDO mount --types proc /proc "$ROOT/proc"
for d in sys dev run; do
    $SUDO mount --rbind "/$d" "$ROOT/$d"
    $SUDO mount --make-rslave "$ROOT/$d"
done
$SUDO install -d "$ROOT/etc/portage/package.accept_keywords" "$ROOT/etc/portage/package.use"
printf '%s\n' "app-admin/calamares ~amd64" |
    $SUDO tee "$ROOT/etc/portage/package.accept_keywords/$SLUG" >/dev/null
printf '%s\n' "sys-kernel/installkernel dracut" "sys-boot/grub grub_platforms_efi-64 mount" "dev-libs/libpwquality python" \
    "dev-libs/libdbusmenu gtk3" |
    $SUDO tee "$ROOT/etc/portage/package.use/$SLUG" >/dev/null
info "Paketliste aktualisieren, Calamares + XFCE + Kernel installieren (10–30 Min.) …"
mark=$(wc -l < "$LOG")
# shellcheck disable=SC2016  # wird im chroot ausgewertet
$SUDO chroot "$ROOT" /bin/bash -c '
    set -e
    source /etc/profile
    # Paketliste fehlt in der LiveGUI bzw. ist alt → anlegen und frisch holen
    mkdir -p /var/db/repos/gentoo
    emerge-webrsync -q
    # Schlüssel für signierte Binärpakete
    command -v getuto >/dev/null && getuto >/dev/null 2>&1 || true
    PKGS="app-admin/calamares sys-kernel/installkernel sys-kernel/gentoo-kernel-bin
        sys-boot/grub sys-boot/efibootmgr sys-fs/dosfstools sys-fs/e2fsprogs sys-apps/gptfdisk
        dev-vcs/git net-misc/rsync
        xfce-base/xfce4-meta x11-terms/xfce4-terminal xfce-extra/xfce4-whiskermenu-plugin
        net-misc/networkmanager gnome-extra/nm-applet"
    # nötige USE-/Keyword-/Lizenz-Änderungen von Portage selbst eintragen lassen (2 Durchgänge)
    for i in 1 2; do
        CONFIG_PROTECT_MASK=/etc/portage emerge --pretend --getbinpkg --noreplace \
            --autounmask=y --autounmask-write=y --autounmask-use=y --autounmask-license=y \
            --autounmask-keep-masks=y $PKGS >/dev/null 2>&1 || true
    done
    emerge --getbinpkg --binpkg-respect-use=y --quiet-build=y --noreplace \
        --autounmask=y --autounmask-use=y --autounmask-license=y --autounmask-continue=y $PKGS
    # WLAN/LAN im Live-System und im installierten System über NetworkManager (Applet in XFCE)
    rc-update add NetworkManager default >/dev/null 2>&1 || true
    for s in dhcpcd wpa_supplicant iwd; do rc-update del "$s" default >/dev/null 2>&1 || true; done
' >>"$LOG" 2>&1 || warn "emerge im Live-System meldete Fehler"
if ! $SUDO chroot "$ROOT" sh -c 'command -v calamares' >/dev/null; then
    printf '  %s--- letzte Fehler aus dem Log ---%s\n' "$D" "$N"
    tail -n +"$((mark + 1))" "$LOG" | grep -E '^!!!|^ \* (ERROR|Error)|emerge: there are no|Cannot resolve|masked by|conflict|failed' | tail -15 | sed 's/^/    /'
    die "Calamares konnte nicht installiert werden (vollständig: $LOG)."
fi
ok "Calamares, XFCE, gentoo-kernel-bin, GRUB im Live-System"

# Live-Desktop: XFCE statt KDE (Autologin-Sitzung umstellen)
if [[ -f $ROOT/usr/share/xsessions/xfce.desktop ]]; then
    while IFS= read -r f; do
        $SUDO sed -i -E 's/^Session=.*/Session=xfce.desktop/; s/^autologin-session=.*/autologin-session=xfce/' "$f"
    done < <($SUDO grep -rlE '^(Session|autologin-session)=' "$ROOT/etc/sddm.conf" "$ROOT/etc/sddm.conf.d" "$ROOT/etc/lightdm" 2>/dev/null)
    ok "Live-Desktop: XFCE"
else
    warn "XFCE-Sitzung nicht gefunden – Live-Desktop bleibt KDE"
fi

# ── 5. Branding, Installer, Gentoo-rice ───────────────────
step "$NAME einrichten: Calamares-Konfiguration, Branding, Rice"
B_DIR="$ROOT/etc/calamares/branding/$SLUG"
$SUDO rm -rf "$ROOT/etc/calamares"
$SUDO cp -r "$REPO/iso/calamares" "$ROOT/etc/calamares"
if [[ $SLUG != darkroot ]]; then $SUDO mv "$ROOT/etc/calamares/branding/darkroot" "$B_DIR"; fi
$SUDO sed -i "s/^branding: .*/branding: $SLUG/" "$ROOT/etc/calamares/settings.conf"
$SUDO sed -i "s/Darkroot OS/$NAME/g; s/\"Darkroot\"/\"${NAME%% *}\"/g; s/^componentName: .*/componentName: $SLUG/" "$B_DIR/branding.desc"
# Logo + Willkommensbild (eigener Schriftzug)
tmpimg=$(mktemp -d)
magick -size 512x512 xc:none -fill '#3b82f6' -draw 'roundrectangle 16,16 495,495 96,96' \
    -fill white -gravity center -pointsize 300 -annotate +0+10 "${NAME:0:1}" "PNG32:$tmpimg/logo.png" 2>>"$LOG" ||
    magick -size 512x512 xc:'#3b82f6' "$tmpimg/logo.png"
magick -size 900x300 gradient:'#0b0b10-#1e293b' -fill white -gravity center -pointsize 72 -annotate +0-20 "$NAME" \
    -fill '#93c5fd' -pointsize 28 -annotate +0+50 "Gentoo · Hyprland · Gentoo-rice" "$tmpimg/welcome.png" 2>>"$LOG" ||
    magick -size 900x300 xc:'#0b0b10' "$tmpimg/welcome.png"
$SUDO cp "$tmpimg"/*.png "$B_DIR/"
rm -rf "$tmpimg"

$SUDO install -m 0755 "$REPO/iso/darkroot-postinstall" "$ROOT/usr/local/bin/darkroot-postinstall"
$SUDO install -m 0755 "$REPO/iso/cli-install" "$ROOT/usr/local/bin/cli-install"
$SUDO sed -i "s/^OS_NAME=.*/OS_NAME=\"$NAME\"/; s/^OS_SLUG=.*/OS_SLUG=\"$SLUG\"/" "$ROOT/usr/local/bin/cli-install"

# Rice (mit .git, damit später "git pull" geht) ins Live-System
$SUDO install -d "$ROOT/opt/darkroot"
$SUDO rm -rf "$ROOT/opt/darkroot/Gentoo-rice"
tar -C "$REPO" --exclude=./iso/work --exclude=./iso/out -cf - . |
    $SUDO tar -C "$ROOT/opt/darkroot" --one-top-level=Gentoo-rice -xf -

# Installer im Startmenü + Autostart im Live-Desktop
$SUDO tee "$ROOT/usr/share/applications/darkroot-installer.desktop" >/dev/null <<EOF
[Desktop Entry]
Type=Application
Name=$NAME installieren
Comment=$NAME auf die Festplatte installieren
Exec=sudo -E calamares
Icon=/etc/calamares/branding/$SLUG/logo.png
Categories=System;
Terminal=false
EOF
$SUDO install -d "$ROOT/etc/xdg/autostart"
$SUDO cp "$ROOT/usr/share/applications/darkroot-installer.desktop" "$ROOT/etc/xdg/autostart/darkroot-installer.desktop"
# Live-Benutzer darf den Installer ohne Passwort starten
echo 'gentoo ALL=(ALL:ALL) NOPASSWD: ALL' | $SUDO tee "$ROOT/etc/sudoers.d/darkroot-live" >/dev/null
$SUDO chmod 0440 "$ROOT/etc/sudoers.d/darkroot-live"

# Konsole: Begrüßung, deutsche Tastatur
$SUDO tee "$ROOT/etc/motd" >/dev/null <<EOF

  $NAME Live – Gentoo + Hyprland (Gentoo-rice)
  Installieren:  Desktop-Symbol "$NAME installieren"  ·  Konsole: sudo cli-install

EOF
if [[ -f $ROOT/etc/conf.d/keymaps ]]; then $SUDO sed -i 's/^keymap=.*/keymap="de-latin1"/' "$ROOT/etc/conf.d/keymaps"; fi

# Paket-Caches nicht in die ISO
cleanup_mounts
$SUDO rm -rf "$ROOT/var/cache/distfiles/"* "$ROOT/var/cache/binpkgs/"* "$ROOT/var/tmp/portage"
ok "Calamares-Branding, Installer-Symbol, Rice in /opt/darkroot"

# ── 6. Bootmenü umbenennen, squashfs packen ───────────────
step "Bootmenü + squashfs (dauert einige Minuten)"
CFGS=()
while IFS= read -r -d '' cfg; do
    if grep -qiE '^[[:space:]]*(menuentry|submenu|menu (label|title))' "$cfg"; then
        # nur Menütitel ändern – nie Labels oder Kernel-Optionen (sonst bootet die ISO nicht)
        sed -i -E "/^[[:space:]]*(menuentry|submenu|[Mm][Ee][Nn][Uu] ([Ll][Aa][Bb][Ee][Ll]|[Tt][Ii][Tt][Ll][Ee]))/ s/Gentoo( Linux)?( LiveGUI)?/$NAME/g" "$cfg"
        CFGS+=("$cfg")
    fi
done < <(find "$ISO_DIR" -name '*.cfg' -print0 2>/dev/null)
rm -f "$SQUASH"
$SUDO mksquashfs "$ROOT" "$SQUASH" -comp xz -b 1M -noappend -quiet >>"$LOG" 2>&1 || die "mksquashfs fehlgeschlagen."
$SUDO chown "$(id -u):$(id -g)" "$SQUASH"
ok "squashfs: $(du -h "$SQUASH" | cut -f1)"

# ── 7. ISO schreiben (Bootsektoren der Original-ISO übernehmen) ─
step "ISO schreiben"
rm -f "$ISO_OUT"
MAPS=(-map "$SQUASH" "/${SQUASH#"$ISO_DIR"/}")
for cfg in "${CFGS[@]}"; do MAPS+=(-map "$cfg" "/${cfg#"$ISO_DIR"/}"); done
xorriso -indev "$base_iso" -outdev "$ISO_OUT" "${MAPS[@]}" -boot_image any replay >>"$LOG" 2>&1 ||
    die "xorriso konnte die ISO nicht schreiben (Details im Log)."
(cd "$OUT" && sha256sum "$(basename "$ISO_OUT")" > "$(basename "$ISO_OUT").sha256")
ok "$(du -h "$ISO_OUT" | cut -f1): ${ISO_OUT/#$HOME/\~}"

if ((!KEEP)); then $SUDO rm -rf "$ISO_DIR" "$ROOT"; fi
print_problems
printf '\n%sFertig:%s %s\n' "$G$B" "$N" "${ISO_OUT/#$HOME/\~}"
printf 'Testen:   Super+D → Virtuelle Maschinen → in Boxes die ISO wählen (UEFI)\n'
printf 'USB-Stick (löscht ALLES darauf – /dev/sdX mit lsblk genau prüfen):\n'
printf '  sudo dd if=%s of=/dev/sdX bs=4M status=progress oflag=sync\n' "${ISO_OUT/#$HOME/\~}"

#!/usr/bin/env bash
# Gentoo-rice – Virtuelle Maschinen (Windows / andere Linux-Distros testen)
#   open    GNOME Boxes öffnen (richtet beim ersten Mal alles ein)     ← Rice-Menü
#   setup   KVM einrichten + GNOME Boxes (Flatpak, kein Kompilieren)
#   pro     zusätzlich virt-manager + libvirt (QEMU/KVM, mehr Optionen; kompiliert ggf. QEMU)
# Copyright (C) 2026 3rr0r303YT – GPL-3.0-or-later
set -uo pipefail
REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
BOXES=org.gnome.Boxes

kvm_setup() {
    step "KVM (Hardware-Virtualisierung)"
    if grep -qE 'svm|vmx' /proc/cpuinfo; then ok "CPU unterstützt Virtualisierung"
    else warn "CPU meldet keine Virtualisierung – im BIOS 'SVM Mode' (AMD) bzw. 'VT-x' (Intel) einschalten"; fi
    local mod=kvm_amd
    grep -q vmx /proc/cpuinfo && mod=kvm_intel
    printf '%s\n' kvm "$mod" | write_root /etc/modules-load.d/gentoo-rice-kvm.conf
    $SUDO modprobe "$mod" 2>/dev/null || true
    if ! getent group kvm >/dev/null; then $SUDO groupadd -r kvm 2>/dev/null || true; fi
    if id -nG | grep -qw kvm; then ok "$(id -un) ist in der Gruppe kvm"
    else $SUDO gpasswd -a "$(id -un)" kvm >/dev/null && ok "$(id -un) zur Gruppe kvm hinzugefügt (wirksam nach Neuanmeldung)"; fi
    if [[ -e /dev/kvm ]]; then ok "/dev/kvm vorhanden"; else warn "/dev/kvm fehlt – nach BIOS-Einstellung neu starten"; fi
}

boxes_setup() {
    step "GNOME Boxes (Flatpak)"
    flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo >>"$LOG" 2>&1 || true
    if flatpak info --user "$BOXES" >/dev/null 2>&1; then ok "GNOME Boxes vorhanden"
    elif flatpak install --user -y --noninteractive flathub "$BOXES"; then ok "GNOME Boxes installiert"
    else warn "GNOME Boxes konnte nicht installiert werden"; FAILED+=("$BOXES (Flatpak)"); fi
    # ISOs aus Downloads auswählbar
    flatpak override --user --filesystem=xdg-download:ro "$BOXES" >>"$LOG" 2>&1 || true
}

pro_setup() {
    step "virt-manager + libvirt (QEMU/KVM)"
    as_dir package.use
    printf '%s\n' "app-emulation/libvirt virt-network qemu" "app-emulation/qemu spice usbredir virgl" \
        "net-dns/dnsmasq script" | write_root /etc/portage/package.use/gentoo-rice-vm
    emerge_pkgs app-emulation/qemu app-emulation/libvirt app-emulation/virt-manager net-dns/dnsmasq \
        "net-firewall/iptables|net-firewall/nftables"
    if [[ -x /etc/init.d/libvirtd ]]; then
        $SUDO rc-update add libvirtd default >>"$LOG" 2>&1 || true
        $SUDO rc-service libvirtd start >>"$LOG" 2>&1 || true
        $SUDO virsh net-autostart default >>"$LOG" 2>&1 || true
        $SUDO virsh net-start default >>"$LOG" 2>&1 || true
        ok "libvirtd läuft (Netzwerk 'default' aktiv)"
    fi
    if getent group libvirt >/dev/null; then $SUDO gpasswd -a "$(id -un)" libvirt >/dev/null 2>&1 || true; fi
    info "Start: virt-manager (im Launcher)"
}

run_setup() { # run_setup [pro]
    TOTAL=2 STEP_LABEL=vm
    if [[ ${1:-} == pro ]]; then TOTAL=3; fi
    # shellcheck source=scripts/lib.sh
    source "$REPO/scripts/lib.sh"
    printf '%s\n' "${B}Gentoo-rice${N} ${D}– Virtuelle Maschinen${N}"
    kvm_setup
    boxes_setup
    if [[ ${1:-} == pro ]]; then pro_setup; fi
    print_problems
    printf '\n%sFertig.%s Windows-ISO: https://www.microsoft.com/software-download/windows11 → in Boxes „+“ → ISO wählen.\n' "$G$B" "$N"
    printf 'Linux-Distros lädt Boxes direkt herunter („+“ → „Betriebssystem herunterladen“). Nach dem ersten Einrichten einmal neu anmelden.\n'
}

case ${1:-open} in
    open)
        if flatpak info --user "$BOXES" >/dev/null 2>&1; then exec flatpak run "$BOXES"; fi
        # shellcheck disable=SC2016  # $1 wird in der Unter-Shell ausgewertet
        exec kitty --class rice-float --hold sh -c '"$1" setup && flatpak run org.gnome.Boxes' sh "$REPO/scripts/vm.sh" ;;
    setup) run_setup ;;
    pro)   run_setup pro ;;
    *) echo "Nutzung: $0 [open|setup|pro]" >&2; exit 1 ;;
esac

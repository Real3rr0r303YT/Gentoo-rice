# Gentoo-rice

🇬🇧 [English](README.md) · 🇩🇪 **Deutsch**

Cleanes, minimalistisches Hyprland-Rice für **Gentoo (OpenRC)** – dunkel, ruhig, mit viel Blur.

![Screenshot](screenshots/desktop.png)
<!-- Screenshot-Platzhalter: screenshots/desktop.png ablegen -->

## Features

- **Hyprland** – 14px Rundung, weiche Schatten, starker Blur, 8px Gaps, Ease-out-Animationen
- **Waybar** als schmale, halbtransparente Menüleiste (Workspaces · WLAN · Audio · CPU · Akku · `Fr 6. Nov 16:18`)
- **Dock** unten mittig (nwg-dock-hyprland), auto-hide, abgerundet, Blur
- **Wofi** als zentrierter Spotlight-Launcher
- **Mako** Notifications oben rechts
- **hyprlock + hypridle** im gleichen Stil
- **Kitty** mit JetBrains Mono, **Inter** als UI-Font
- **fastfetch** mit Gentoo-Logo im Rice-Look, startet beim Öffnen von Kitty
- **Firefox** (`firefox-bin`) als Standardbrowser: Wayland nativ, dunkel & kompakt, abgerundete Tabs (`userChrome.css`), Telemetrie aus, strenger Tracking-Schutz, uBlock Origin
- **WhiteSur** GTK-, Icon- und Cursor-Theme
- Selbst generiertes Verlaufs-Wallpaper (`scripts/gen-wallpaper.sh`)
- **Gaming:** Mesa/RADV für Radeon 780M, Flatpak + Flathub, Steam, gamemode, MangoHud

| Farbe | Wert |
|---|---|
| Hintergrund | `#1C1C1E` |
| Flächen | `#2C2C2E` |
| Text | `#F5F5F7` |
| Akzent | `#0A84FF` |
| Linien | `rgba(255,255,255,0.08)` |

## Installation

```sh
git clone https://github.com/Real3rr0r303YT/Gentoo-rice && cd Gentoo-rice && ./install.sh
```

Als normaler Benutzer starten – `sudo`/`doas` wird nur für Systemschritte genutzt.
Das Skript ist mehrfach ausführbar. Vorhandene Configs werden nach
`~/.config-backup/gentoo-rice/<Datum>/` gesichert.

Danach neu starten und auf **TTY1** einloggen → Hyprland startet automatisch.

Steam-Startoptionen für Spiele: `gamemoderun mangohud %command%`

### Deinstallation

```sh
./uninstall.sh
```

Entfernt die Symlinks (inkl. fastfetch und Firefox-Profil), den Autostart, den fastfetch-Eintrag in `~/.bashrc` und die Firefox-Policies und spielt das Backup zurück.

## Firefox

- Installiert `www-client/firefox-bin` (kein Kompilieren) und setzt ihn als Standardbrowser (`xdg-mime`/`xdg-settings` für http, https, HTML)
- `firefox/user.js` + `firefox/userChrome.css` werden ins Standardprofil verlinkt (Profil wird bei Bedarf headless angelegt)
- `firefox/policies.json` → `/etc/firefox/policies/` und `/opt/firefox/distribution/`: Telemetrie aus, Tracking-Schutz streng, uBlock Origin wird automatisch installiert
- Im Dock angepinnt, `Super + B` öffnet Firefox

## Dev-Setup

Optionales Entwickler-Setup – zusammen mit dem Rice oder einzeln:

```sh
./install.sh --dev          # Rice + Dev-Setup
./scripts/dev-setup.sh      # nur Dev-Setup
```

| Bereich | Inhalt |
|---|---|
| Editor | VS Code (`app-editors/vscode`, Lizenz wird freigegeben), Neovim |
| KI | Claude Code über den offiziellen nativen Installer, PATH in `~/.bashrc` |
| Extensions | Claude Code, Python, Pylance, GitLens, Error Lens, GitHub Theme |
| VS-Code-Look | JetBrains Mono + Ligaturen, Rice-Farben, Custom-Titelleiste, Smooth Scrolling, Wayland (`~/.config/code-flags.conf`) |
| Python | `dev-lang/python`, pip, pipx (`pipx ensurepath`), venv |
| Tools | git, GitHub CLI, Node.js + npm, gcc, clang, cmake, make, ripgrep, fd, jq, htop, btop, curl, wget |
| Git | fragt Name/E-Mail ab, falls nicht gesetzt |

Mehrfach ausführbar; nicht verfügbare Pakete werden gemeldet und übersprungen.
Eine vorhandene `settings.json` wird vor dem Ersetzen gesichert (`settings.json.bak-<Datum>`).
Am Ende erscheint eine Übersicht der installierten Versionen.

## Keybinds

| Taste | Aktion |
|---|---|
| `Super + Enter` | Terminal (Kitty) |
| `Super + Leertaste` | Launcher |
| `Super + E` | Dateimanager |
| `Super + B` | Firefox |
| `Super + Q` | Fenster schließen |
| `Super + F` | Vollbild |
| `Super + V` | Schwebend umschalten |
| `Super + P` | Pseudo-Tiling |
| `Super + J` | Split umschalten |
| `Super + L` | Bildschirm sperren |
| `Super + Shift + E` | Power-Menü |
| `Super + Shift + R` | Hyprland neu laden |
| `Super + 1–6` | Workspace wechseln |
| `Super + Shift + 1–6` | Fenster auf Workspace verschieben |
| `Super + Pfeiltasten` | Fokus wechseln |
| `Super + Shift + Pfeiltasten` | Fenster verschieben |
| `Super + Mausrad` | Workspace wechseln |
| `Super + LMB / RMB` | Fenster bewegen / skalieren |
| `Print` | Screenshot (Bereich) |
| `Shift + Print` | Screenshot (Bildschirm) |
| Medientasten | Lautstärke / Helligkeit |
| 3-Finger-Wischen | Workspace wechseln (Hyprland ≥ 0.53) |

## Struktur

```
hypr/        hyprland.conf, hyprlock.conf, hypridle.conf, compat/
waybar/      config.jsonc, style.css
kitty/       kitty.conf
wofi/        config, style.css
mako/        config
gtk/         gtk-3.0 / gtk-4.0 settings.ini
nwg-dock-hyprland/  style.css
wallpapers/  gradient.png
vscode/      settings.json, code-flags.conf
fastfetch/   config.jsonc
firefox/     user.js, userChrome.css, policies.json
scripts/     Hilfsskripte
```

## Unterstützen

☕ [Buy me a coffee](https://buymeacoffee.com/3rr0r303YT)

## Lizenz

Copyright © 2026 3rr0r303YT

Dieses Projekt steht unter der **GNU General Public License v3.0** – siehe [LICENSE](LICENSE).
Du darfst es nutzen, verändern und weitergeben, solange abgeleitete Werke ebenfalls unter der GPL-3.0 stehen.
Die WhiteSur-Themes werden zur Installationszeit aus ihren Original-Repositories geladen und unterliegen deren Lizenzen.

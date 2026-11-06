# Gentoo-rice

🇬🇧 [English](README.md) · 🇩🇪 **Deutsch**

Wallpaper-basiertes **Anime-/Lofi**-Hyprland-Rice für **Gentoo (OpenRC)** – alle Farben kommen aus dem aktuellen Wallpaper.

| Desktop | Wallpaper-Picker | Terminal-Spielzeug |
|---|---|---|
| ![Desktop](screenshots/desktop.png) | ![Picker](screenshots/picker.png) | ![Spielzeug](screenshots/toys.png) |

<!-- Screenshot-Platzhalter: desktop.png, picker.png, toys.png in screenshots/ ablegen -->

## Features

- **Dynamische Farben** mit pywal16: Hyprland-Borders, Waybar, kitty, rofi, mako, cava, btop, fastfetch und hyprlock werden bei jedem Wallpaper-Wechsel neu eingefärbt
- **Hyprland** – halbtransparente Fenster, starker Blur, 10px Rundung, dünner Akzent-Border (Verlauf), 10px Gaps, Popin-/Slide-Animationen
- **Waybar** als drei schwebende Inseln:
  links Media-Player (prev/play/next + Titel über playerctl) · Mitte Workspace-Pills (aktiver breiter, in Akzentfarbe) · rechts CPU, RAM, Lautstärke, WLAN, Bluetooth, Akku, Uhrzeit, Power
- **Wallpaper:** Bilder über swww/awww mit Übergangsanimation, Videos über mpvpaper
- **Wallpaper-Picker** (`Super + W`): horizontale Leiste unten mit gecachten ffmpeg-Vorschaubildern, Videos mit **VIDEO**-Badge
- **Wallpaper Engine** Live-Wallpaper aus Steam (optional, `./install.sh --we`)
- **Terminal-Spielzeug** als schwebende Fenster: cava, btop, cmatrix, tty-clock, fastfetch (Gentoo-Logo), Songtext-Overlay (sptlrx)
- **hyprlock** in denselben dynamischen Farben, zeigt den aktuellen Song
- **Claude Code** standardmäßig über den offiziellen nativen Installer (`Super + K` öffnet es im Terminal)
- **Firefox**, rofi-Launcher, mako-Benachrichtigungen, Papirus-Icons, Bibata-Cursor
- **Gaming:** Mesa/RADV für Radeon 780M, Vulkan-Tools, Flatpak + Flathub, Steam (Flatpak), gamemode, MangoHud (nativ + Flatpak-Layer); Steam und Spiele ohne Blur/Transparenz, Spiele im Vollbild mit Tearing für niedrige Latenz

## Installation

```sh
git clone https://github.com/Real3rr0r303YT/Gentoo-rice && cd Gentoo-rice && ./install.sh
```

```sh
./install.sh --dry-run   # nur anzeigen, was installiert/geändert würde (kein sudo, keine Änderungen)
./install.sh --no-claude # ohne Claude Code
```

Als normaler Benutzer starten – `sudo`/`doas` wird nur für Systemschritte genutzt.
Jeder Lauf wird nach `~/.cache/gentoo-rice/install.log` geloggt. Vor dem Bauen macht emerge einen Probelauf (`--pretend`); nötige USE-/Keyword-/Lizenz-Änderungen werden automatisch übernommen (autounmask + `etc-update --automode -5`). Schlägt der Sammel-emerge fehl, werden die Pakete einzeln nachinstalliert und alle Fehlschläge am Ende aufgelistet.
Das Skript ist mehrfach ausführbar; nicht verfügbare Pakete werden gemeldet und übersprungen.
Vorhandene Configs werden nach `~/.config-backup/gentoo-rice/<Datum>/` gesichert.

Danach neu starten und auf **TTY1** einloggen → Hyprland startet automatisch.

### Wallpaper

Bilder (`jpg png webp gif`) oder Videos (`mp4 mkv webm mov`) nach **`~/Pictures/wallpapers`** legen.
Mitgeliefert werden nur drei selbst generierte Verlaufs-Platzhalter – keine fremden Bilder.

```sh
~/.local/share/gentoo-rice/scripts/wallpaper.sh set <datei>   # setzen + Farben neu erzeugen
~/.local/share/gentoo-rice/scripts/wallpaper.sh random
~/.local/share/gentoo-rice/scripts/gen-wallpaper.sh 2880x1800 # neuer Verlaufs-Platzhalter
```

### Steam

`Super + G` öffnet Steam. Startoptionen für Spiele: `gamemoderun mangohud %command%`

### Deinstallation

```sh
./uninstall.sh
```

Entfernt alle Symlinks (auch alte wofi-/mako-/Dock-Links, fastfetch, Firefox-Profildateien), den Autostart, den fastfetch-Eintrag in `~/.bashrc`, die Firefox-Policies, die Platzhalter-Wallpaper und den Thumbnail-Cache und spielt das Backup zurück.

## Wallpaper Engine

Live-Wallpaper aus **Wallpaper Engine** (Steam) über [linux-wallpaperengine](https://github.com/Almamu/linux-wallpaperengine) von Almamu.

**Voraussetzungen**

- Wallpaper Engine **in Steam gekauft und installiert** (App-ID 431960) – Assets und Workshop-Wallpaper kommen von dort
- Steam als Flatpak (`~/.var/app/com.valvesoftware.Steam/.local/share/Steam`) oder nativ (`~/.local/share/Steam`); weitere Bibliotheken aus `libraryfolders.vdf` werden automatisch erkannt

**Installation**

```sh
./install.sh --we                 # Rice + Wallpaper Engine
./scripts/wallpaperengine.sh      # nur Wallpaper Engine (erneut ausführen = git pull + neu bauen)
```

Installiert die Build-Abhängigkeiten per emerge, klont das Repo mit Submodulen nach `~/.local/src/linux-wallpaperengine`, baut es mit cmake und installiert es nach `~/.local/bin`.

**Nutzung**

- Wallpaper im Steam-Workshop abonnieren → `Super + W` zeigt sie mit **WE**-Badge und Titel aus `project.json` (Typen `scene` und `video`; `web` als experimentell markiert)
- Direkt: `~/.local/share/gentoo-rice/scripts/we-set.sh <Workshop-ID|Ordner>` · beenden: `we-set.sh stop`
- Die Rice-Farben werden aus `preview.jpg/gif` des Wallpapers erzeugt
- Das zuletzt gewählte Wallpaper wird beim Hyprland-Start wiederhergestellt
- Einstellungen in `~/.config/gentoo-rice/wallpaperengine.conf`: FPS (Standard 30), Ton (Standard `--silent`), Automute, Skalierung, **Pause bei Vollbild-Fenstern** (Standard an, über Hyprland-Socket-Events), zusätzliche Argumente
- Startet linux-wallpaperengine nicht, wird das Vorschaubild über swww gezeigt und ein Fehler per Benachrichtigung gemeldet (Log: `~/.cache/rice/linux-wallpaperengine.log`)

**Bekannte Einschränkungen**

- Nicht jede Szene wird korrekt dargestellt – linux-wallpaperengine unterstützt nicht alle Effekte von Wallpaper Engine
- `web`-Wallpaper sind experimentell, `application`-Wallpaper werden nicht unterstützt
- Benutzer-Eigenschaften aus der Wallpaper-Engine-Oberfläche werden nicht automatisch übernommen
- Pausieren hält den Prozess an (SIGSTOP) – das letzte Bild bleibt sichtbar
- Es werden keine Wallpaper oder Workshop-Inhalte mitgeliefert

## Claude Code

`install.sh` installiert [Claude Code](https://claude.ai/code) über den offiziellen nativen Installer (`curl -fsSL https://claude.ai/install.sh | bash`), ergänzt `~/.local/bin` im `PATH` (`~/.bashrc`) und prüft `claude --version`. Danach aktualisiert sich Claude Code selbst.

```sh
claude                              # im aktuellen Ordner starten (beim ersten Start Login im Browser)
./scripts/install-claude-code.sh    # nur Claude Code installieren/prüfen
```

`Super + K` öffnet Claude Code in einem neuen Terminal. Das komplette Entwickler-Setup (`--dev`) bringt zusätzlich VS Code mit der Claude-Code-Extension.

## Firefox

- Installiert `www-client/firefox-bin` (kein Kompilieren) und setzt ihn als Standardbrowser (`xdg-mime`/`xdg-settings` für http, https, HTML)
- `firefox/user.js` + `firefox/userChrome.css` werden ins Standardprofil verlinkt (Profil wird bei Bedarf headless angelegt)
- `firefox/policies.json` → `/etc/firefox/policies/` und `/opt/firefox/distribution/`: Telemetrie aus, Tracking-Schutz streng, uBlock Origin wird automatisch installiert
- `Super + B` öffnet Firefox (immer deckend)

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
| `Super + Enter` | Terminal (kitty) |
| `Super + Leertaste` | Launcher (rofi) |
| `Super + W` | Wallpaper-Picker (Bilder, Videos, Wallpaper Engine) |
| `Super + Shift + W` | Zufälliges Wallpaper |
| `Super + B` | Firefox |
| `Super + G` | Steam |
| `Super + E` | Dateimanager |
| `Super + A` | cava (Audio-Visualizer) |
| `Super + T` | btop |
| `Super + M` | cmatrix |
| `Super + C` | tty-clock |
| `Super + I` | fastfetch |
| `Super + Y` | Songtext-Overlay (an/aus) |
| `Super + K` | Claude Code (Terminal) |
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
| `Print` / `Shift + Print` | Screenshot Bereich / Bildschirm |
| Medientasten | Lautstärke, Helligkeit, Play/Pause, Weiter/Zurück |
| 3-Finger-Wischen | Workspace wechseln (Hyprland ≥ 0.53) |

## Struktur

```
hypr/        hyprland.lua (Lua-Config, neues Hyprland z. B. 0.57), hyprland.conf + compat/ (ältere hyprlang-Versionen),
             hyprlock.conf, hypridle.conf
waybar/      config.jsonc, style.css (colors.css → generiert)
kitty/       kitty.conf (colors-wal.conf → generiert)
rofi/        config.rasi (Launcher), wallpaper.rasi (Picker), menu.rasi
wal/         templates/ für pywal16 (Hyprland, Waybar, rofi, mako, cava)
fastfetch/   config.jsonc
firefox/     user.js, userChrome.css, policies.json
gtk/         gtk-3.0 / gtk-4.0 settings.ini
vscode/      settings.json, code-flags.conf
wallpapers/  3 generierte Verlaufs-Platzhalter
config/      wallpaperengine.conf (Vorlage)
scripts/     wallpaper.sh, wallpaper-picker.sh, we-set.sh, install-claude-code.sh, dev-setup.sh, …
```

## Unterstützen

☕ [Buy me a coffee](https://buymeacoffee.com/3rr0r303YT)

## Lizenz

Copyright © 2026 3rr0r303YT

Dieses Projekt steht unter der **GNU General Public License v3.0** – siehe [LICENSE](LICENSE).
Du darfst es nutzen, verändern und weitergeben, solange abgeleitete Werke ebenfalls unter der GPL-3.0 stehen.
Bibata-Cursor und sptlrx werden zur Installationszeit aus ihren Original-Releases geladen und unterliegen deren Lizenzen.

# Gentoo-rice

🇬🇧 **English** · 🇩🇪 [Deutsch](README.de.md)

A clean, minimal Hyprland rice for **Gentoo (OpenRC)** – dark, calm, lots of blur.

![Screenshot](screenshots/desktop.png)
<!-- Screenshot placeholder: put screenshots/desktop.png here -->

## Features

- **Hyprland** – 14px rounding, soft shadows, strong blur, 8px gaps, ease-out animations
- **Waybar** as a slim, translucent menu bar (workspaces · Wi-Fi · audio · CPU · battery · clock)
- **Dock** bottom center (nwg-dock-hyprland), auto-hide, rounded, blur
- **Wofi** as a centered spotlight-style launcher
- **Mako** notifications top right
- **hyprlock + hypridle** in the same style
- **Kitty** with JetBrains Mono, **Inter** as UI font
- **fastfetch** with Gentoo logo in the rice look, runs when Kitty opens
- **Firefox** (`firefox-bin`) as default browser: native Wayland, dark & compact, rounded tabs (`userChrome.css`), telemetry off, strict tracking protection, uBlock Origin
- **WhiteSur** GTK, icon and cursor theme
- Self-generated gradient wallpaper (`scripts/gen-wallpaper.sh`)
- **Gaming:** Mesa/RADV for Radeon 780M, Flatpak + Flathub, Steam, gamemode, MangoHud

| Color | Value |
|---|---|
| Background | `#1C1C1E` |
| Surfaces | `#2C2C2E` |
| Text | `#F5F5F7` |
| Accent | `#0A84FF` |
| Lines | `rgba(255,255,255,0.08)` |

## Installation

```sh
git clone https://github.com/Real3rr0r303YT/Gentoo-rice && cd Gentoo-rice && ./install.sh
```

Run as a normal user – `sudo`/`doas` is only used for system steps.
The script can be run repeatedly. Existing configs are backed up to
`~/.config-backup/gentoo-rice/<date>/`.

Reboot afterwards and log in on **TTY1** → Hyprland starts automatically.

Steam launch options for games: `gamemoderun mangohud %command%`

### Uninstall

```sh
./uninstall.sh
```

Removes the symlinks (including fastfetch and the Firefox profile files), the autostart, the fastfetch entry in `~/.bashrc` and the Firefox policies, then restores the backup.

## Firefox

- Installs `www-client/firefox-bin` (no compiling) and sets it as default browser (`xdg-mime`/`xdg-settings` for http, https, HTML)
- `firefox/user.js` + `firefox/userChrome.css` are linked into the default profile (created headless if missing)
- `firefox/policies.json` → `/etc/firefox/policies/` and `/opt/firefox/distribution/`: telemetry off, strict tracking protection, uBlock Origin installed automatically
- Pinned to the dock, `Super + B` opens Firefox

## Dev setup

Optional developer setup – together with the rice or standalone:

```sh
./install.sh --dev          # rice + dev setup
./scripts/dev-setup.sh      # dev setup only
```

| Area | Content |
|---|---|
| Editor | VS Code (`app-editors/vscode`, license accepted), Neovim |
| AI | Claude Code via the official native installer, PATH in `~/.bashrc` |
| Extensions | Claude Code, Python, Pylance, GitLens, Error Lens, GitHub Theme |
| VS Code look | JetBrains Mono + ligatures, rice colors, custom title bar, smooth scrolling, Wayland (`~/.config/code-flags.conf`) |
| Python | `dev-lang/python`, pip, pipx (`pipx ensurepath`), venv |
| Tools | git, GitHub CLI, Node.js + npm, gcc, clang, cmake, make, ripgrep, fd, jq, htop, btop, curl, wget |
| Git | asks for name/email if not set |

Re-runnable; unavailable packages are reported and skipped.
An existing `settings.json` is backed up before replacing (`settings.json.bak-<date>`).
A summary of installed versions is printed at the end.

## Keybinds

| Key | Action |
|---|---|
| `Super + Enter` | Terminal (Kitty) |
| `Super + Space` | Launcher |
| `Super + E` | File manager |
| `Super + B` | Firefox |
| `Super + Q` | Close window |
| `Super + F` | Fullscreen |
| `Super + V` | Toggle floating |
| `Super + P` | Pseudo tiling |
| `Super + J` | Toggle split |
| `Super + L` | Lock screen |
| `Super + Shift + E` | Power menu |
| `Super + Shift + R` | Reload Hyprland |
| `Super + 1–6` | Switch workspace |
| `Super + Shift + 1–6` | Move window to workspace |
| `Super + Arrow keys` | Move focus |
| `Super + Shift + Arrow keys` | Move window |
| `Super + Mouse wheel` | Switch workspace |
| `Super + LMB / RMB` | Move / resize window |
| `Print` | Screenshot (area) |
| `Shift + Print` | Screenshot (screen) |
| Media keys | Volume / brightness |
| 3-finger swipe | Switch workspace (Hyprland ≥ 0.53) |

## Structure

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
scripts/     helper scripts
```

## Support

☕ [Buy me a coffee](https://buymeacoffee.com/3rr0r303YT)

## License

Copyright © 2026 3rr0r303YT

This project is licensed under the **GNU General Public License v3.0** – see [LICENSE](LICENSE).
You may use, modify and redistribute it as long as derivative works are also licensed under GPL-3.0.
The WhiteSur themes are downloaded from their original repositories at install time and are subject to their own licenses.

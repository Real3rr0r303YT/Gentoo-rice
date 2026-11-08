-- Gentoo-rice – Hyprland (Lua-Config, Hyprland >= 0.55)
-- Anime/Lofi-Look, Farben kommen aus dem Wallpaper (pywal16)
-- Copyright (C) 2026 3rr0r303YT – GPL-3.0-or-later
--
-- Ältere Hyprland-Versionen (hyprlang) nutzen weiterhin hyprland.conf.

local home    = os.getenv("HOME") or ""
local rice    = home .. "/.local/share/gentoo-rice"
local scripts = rice .. "/scripts"

---------------------
---- FARBEN ---------
---------------------

-- Wird von scripts/wallpaper.sh bei jedem Wallpaper-Wechsel neu erzeugt (Template: wal/templates/colors-hyprland.lua)
local c = {
    background = "rgb(16131f)",
    foreground = "rgb(f2f0f8)",
    accent     = "rgb(7aa2f7)",
    accent2    = "rgb(bb9af7)",
    muted      = "rgba(4a445899)",
}
local ok, wal = pcall(dofile, home .. "/.cache/wal/colors-hyprland.lua")
if ok and type(wal) == "table" then
    for k, v in pairs(wal) do c[k] = v end
end

-- Optik des aktiven Themes (scripts/theme.sh → ~/.cache/rice/theme-hypr.lua)
local look = {
    gaps_in = 5, gaps_out = 10, rounding = 10, border_size = 2,
    active_opacity = 0.85, inactive_opacity = 0.75, blur_size = 12, blur_passes = 4,
    cursor = "Bibata-Modern-Ice", cursor_size = 24,
}
local ok_look, theme_look = pcall(dofile, home .. "/.cache/rice/theme-hypr.lua")
if ok_look and type(theme_look) == "table" then
    for k, v in pairs(theme_look) do look[k] = v end
end

-- Gaming-Modus (scripts/gaming-mode.sh → ~/.cache/rice/gaming.lua): keine Effekte, keine Lücken
local ok_gm, gm = pcall(dofile, home .. "/.cache/rice/gaming.lua")
local gaming = ok_gm and gm == true
if gaming then
    look.gaps_in, look.gaps_out, look.rounding = 0, 0, 0
    look.active_opacity, look.inactive_opacity = 1.0, 1.0
end

---------------------
---- PROGRAMME ------
---------------------

local terminal = "kitty"
local float    = "kitty --class rice-float -o remember_window_size=no"
local menu     = "pkill rofi || rofi -show drun"
local files    = "thunar"
local browser  = "firefox-bin"
local steam    = "flatpak run com.valvesoftware.Steam"
local spotify  = "flatpak run com.spotify.Client"

---------------------
---- MONITORE -------
---------------------

hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})

---------------------
---- UMGEBUNG -------
---------------------

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
-- Flatpak-Apps (Steam, Spotify, Minecraft …) im Launcher anzeigen
hl.env("XDG_DATA_DIRS", home .. "/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:/usr/local/share:/usr/share")
hl.env("XCURSOR_THEME", look.cursor)
hl.env("XCURSOR_SIZE", tostring(look.cursor_size))
hl.env("HYPRCURSOR_THEME", look.cursor)
hl.env("HYPRCURSOR_SIZE", tostring(look.cursor_size))
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

---------------------
---- AUTOSTART ------
---------------------

hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_DATA_DIRS HYPRLAND_INSTANCE_SIGNATURE")
    hl.exec_cmd("gentoo-pipewire-launcher restart")
    hl.exec_cmd(scripts .. "/cursor.sh " .. look.cursor .. " " .. look.cursor_size)
    hl.exec_cmd(scripts .. "/wallpaper.sh restore")
    hl.exec_cmd("waybar")
    hl.exec_cmd("mako -c " .. home .. "/.cache/wal/mako-config")
    hl.exec_cmd("hypridle")
    hl.exec_cmd(scripts .. "/antivirus.sh watch")
    hl.exec_cmd(scripts .. "/polkit.sh")
end)

---------------------
---- LOOK -----------
---------------------

hl.config({
    general = {
        gaps_in          = look.gaps_in,
        gaps_out         = look.gaps_out,
        border_size      = look.border_size,
        col = {
            active_border   = { colors = { c.accent, c.accent2 }, angle = 45 },
            inactive_border = c.muted,
        },
        layout           = "dwindle",
        resize_on_border = true,
        allow_tearing    = true,
    },

    decoration = {
        rounding           = look.rounding,
        active_opacity     = look.active_opacity,
        inactive_opacity   = look.inactive_opacity,
        fullscreen_opacity = 1.0,

        blur = {
            enabled           = not gaming,
            size              = look.blur_size,
            passes            = look.blur_passes,
            new_optimizations = true,
            ignore_opacity    = true,
            noise             = 0.02,
            contrast          = 1.0,
            brightness        = 0.85,
            vibrancy          = 0.25,
            popups            = true,
        },

        shadow = {
            enabled      = not gaming,
            range        = 24,
            render_power = 3,
            color        = "rgba(00000088)",
        },
    },

    animations = {
        enabled = not gaming,
    },

    dwindle = {
        preserve_split = true,
    },

    misc = {
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        force_default_wallpaper  = 0,
        background_color         = c.background,
    },

    input = {
        kb_layout     = "de",
        follow_mouse  = 1,
        mouse_refocus = false,     -- Fokus springt nicht beim bloßen Drüberfahren über Lücken
        sensitivity   = 0,
        accel_profile = "flat",    -- lineare Bewegung, kein "Schwimmen" (Gaming-freundlich)
        scroll_factor = 1.0,
        touchpad = {
            natural_scroll       = true,
            tap_to_click         = true,
            disable_while_typing = true,
            clickfinger_behavior = true,   -- 2 Finger = Rechtsklick, 3 Finger = Mittelklick
            scroll_factor        = 0.6,    -- sanfteres Scrollen
        },
    },

    cursor = {
        enable_hyprcursor    = true,   -- gestochen scharf bei jeder Skalierung
        sync_gsettings_theme = true,   -- gleicher Zeiger in GTK-Apps
        inactive_timeout     = 5,      -- nach 5 s ohne Bewegung ausblenden
        hide_on_key_press    = true,   -- beim Tippen ausblenden
        no_warps             = true,   -- Zeiger springt nicht bei Fokuswechsel per Tastatur
    },

    ecosystem = {
        no_update_news  = true,
        no_donation_nag = true,
    },
})

-- Weiche Popin-/Slide-Animationen
hl.curve("soft",     { type = "bezier", points = { {0.22, 1},    {0.36, 1} } })
hl.curve("overshot", { type = "bezier", points = { {0.34, 1.4},  {0.64, 1} } })
hl.curve("smooth",   { type = "bezier", points = { {0.25, 0.1},  {0.25, 1} } })
hl.curve("linear",   { type = "bezier", points = { {0, 0},       {1, 1} } })

hl.animation({ leaf = "windows",     enabled = true, speed = 5,  bezier = "overshot", style = "popin 80%" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 4,  bezier = "smooth",   style = "popin 80%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 5,  bezier = "soft",     style = "slide" })
hl.animation({ leaf = "border",      enabled = true, speed = 8,  bezier = "smooth" })
hl.animation({ leaf = "fade",        enabled = true, speed = 5,  bezier = "smooth" })
hl.animation({ leaf = "layers",      enabled = true, speed = 4,  bezier = "soft",     style = "slide" })
hl.animation({ leaf = "workspaces",  enabled = true, speed = 5,  bezier = "soft",     style = "slidefade 20%" })

hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})

---------------------
---- REGELN ---------
---------------------

hl.window_rule({
    name           = "suppress-maximize",
    match          = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name  = "float-tools",
    match = { class = "^(pavucontrol|org.pulseaudio.pavucontrol|nm-connection-editor|blueman-manager)$" },
    float = true,
})

-- Terminal-Spielzeug (cava, btop, cmatrix, tty-clock, fastfetch)
hl.window_rule({
    name   = "rice-float",
    match  = { class = "^(rice-float)$" },
    float  = true,
    center = true,
})

-- Songtext-Overlay
hl.window_rule({
    name     = "rice-lyrics",
    match    = { class = "^(rice-lyrics)$" },
    float    = true,
    pin      = true,
    no_focus = true,
})

-- kitty bringt eigene Transparenz mit, Browser/Medien bleiben deckend
hl.window_rule({
    name   = "opaque-apps",
    match  = { class = "^(kitty|firefox|firefox-bin|mpv|vlc|imv)$" },
    opaque = true,
})

-- Steam & Spiele: kein Blur, keine Transparenz
hl.window_rule({
    name    = "steam-opaque",
    match   = { class = "^(steam|Steam|steam_app_.*|gamescope)$" },
    opaque  = true,
    no_blur = true,
})

-- Spiele: Vollbild + Tearing (niedrige Latenz)
hl.window_rule({
    name       = "games-fullscreen",
    match      = { class = "^(steam_app_.*|gamescope)$" },
    fullscreen = true,
    immediate  = true,
})

-- Blur für Waybar, rofi und Benachrichtigungen
hl.layer_rule({
    name         = "rice-layer-blur",
    match        = { namespace = "^(waybar|rofi|notifications)$" },
    blur         = true,
    ignore_alpha = 0.3,
})

---------------------
---- TASTEN ---------
---------------------

local mod = "SUPER"
local function exec(cmd) return hl.dsp.exec_cmd(cmd) end

hl.bind(mod .. " + Return",      exec(terminal))
hl.bind(mod .. " + Space",       exec(menu))
hl.bind(mod .. " + E",           exec(files))
hl.bind(mod .. " + B",           exec(browser))
hl.bind(mod .. " + G",           exec(steam))
hl.bind(mod .. " + SHIFT + G",   exec(scripts .. "/gaming-mode.sh toggle"))
hl.bind(mod .. " + S",           exec(spotify))
hl.bind(mod .. " + W",           exec(scripts .. "/wallpaper-picker.sh"))
hl.bind(mod .. " + SHIFT + W",   exec(scripts .. "/wallpaper.sh random"))
hl.bind(mod .. " + SHIFT + T",   exec(scripts .. "/theme-picker.sh"))
hl.bind(mod .. " + D",           exec(scripts .. "/rice-menu.sh"))
hl.bind(mod .. " + Q",           hl.dsp.window.close())
hl.bind(mod .. " + F",           exec(browser))
hl.bind(mod .. " + SHIFT + F",   hl.dsp.window.fullscreen())
hl.bind(mod .. " + V",           hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + P",           hl.dsp.window.pseudo())
hl.bind(mod .. " + J",           hl.dsp.layout("togglesplit"))
hl.bind(mod .. " + L",           exec("loginctl lock-session"))
hl.bind(mod .. " + SHIFT + E",   exec(scripts .. "/powermenu.sh"))
hl.bind(mod .. " + SHIFT + R",   hl.dsp.reload_config())

-- Terminal-Spielzeug (schwebend)
hl.bind(mod .. " + A", exec(float .. " -o initial_window_width=100c -o initial_window_height=18c sh -c 'cava -p ~/.cache/wal/cava-config'"))
hl.bind(mod .. " + T", exec(float .. " -o initial_window_width=130c -o initial_window_height=38c btop"))
hl.bind(mod .. " + M", exec(float .. " -o initial_window_width=110c -o initial_window_height=32c cmatrix -ab -C blue"))
hl.bind(mod .. " + C", exec(float .. " -o initial_window_width=70c -o initial_window_height=12c tty-clock -cbs -C 4"))
hl.bind(mod .. " + I", exec(float .. " -o initial_window_width=90c -o initial_window_height=24c --hold sh -c 'GENTOO_RICE_FASTFETCH=1 fastfetch'"))
hl.bind(mod .. " + Y", exec(scripts .. "/lyrics.sh"))

-- Claude Code im Terminal (Shell bleibt danach offen)
hl.bind(mod .. " + K", exec("kitty --class claude-code sh -c 'cd ~ && claude; exec bash'"))

-- Screenshots
hl.bind("Print",         exec(scripts .. "/screenshot.sh area"))
hl.bind("SHIFT + Print", exec(scripts .. "/screenshot.sh full"))

-- Fokus / Fenster verschieben
for _, d in ipairs({ "left", "right", "up", "down" }) do
    hl.bind(mod .. " + " .. d,             hl.dsp.focus({ direction = d }))
    hl.bind(mod .. " + SHIFT + " .. d,     hl.dsp.window.move({ direction = d }))
end

-- Arbeitsflächen 1–6
for i = 1, 6 do
    hl.bind(mod .. " + " .. i,         hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Maus: bewegen / skalieren
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Medientasten
hl.bind("XF86AudioRaiseVolume",  exec("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  exec("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),        { locked = true, repeating = true })
hl.bind("XF86AudioMute",         exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),       { locked = true })
hl.bind("XF86AudioMicMute",      exec("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),     { locked = true })
hl.bind("XF86AudioPlay",         exec("playerctl play-pause"),                             { locked = true })
hl.bind("XF86AudioPause",        exec("playerctl play-pause"),                             { locked = true })
hl.bind("XF86AudioNext",         exec("playerctl next"),                                   { locked = true })
hl.bind("XF86AudioPrev",         exec("playerctl previous"),                               { locked = true })
hl.bind("XF86MonBrightnessUp",   exec("brightnessctl -e4 -n2 set 5%+"),                    { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", exec("brightnessctl -e4 -n2 set 5%-"),                    { locked = true, repeating = true })

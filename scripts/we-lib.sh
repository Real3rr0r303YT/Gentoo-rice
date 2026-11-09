# shellcheck shell=bash disable=SC2034  # WE_*-Variablen werden von den aufrufenden Skripten genutzt
# Gentoo-rice – Wallpaper-Engine-Helfer (Steam-Pfade, project.json, Konfiguration)
# Copyright (C) 2026 3rr0r303YT – GPL-3.0-or-later

WE_APPID=431960
WE_CONF="$HOME/.config/gentoo-rice/wallpaperengine.conf"
WE_STATE="$HOME/.cache/rice"
WE_BIN="$HOME/.local/bin/linux-wallpaperengine"

we_load_config() {
    WE_FPS=30 WE_SILENT=1 WE_AUTOMUTE=1 WE_PAUSE_ON_FULLSCREEN=1 WE_SCALING=fill WE_EXTRA_ARGS="" WE_STEAM_LIBRARIES=""
    # shellcheck source=/dev/null
    [[ -f $WE_CONF ]] && source "$WE_CONF"
    return 0
}

# Steam-Wurzeln: Flatpak und nativ
we_steam_roots() {
    local r
    for r in "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam" \
             "$HOME/.var/app/com.valvesoftware.Steam/data/Steam" \
             "$HOME/.local/share/Steam" "$HOME/.steam/steam"; do
        if [[ -d $r/steamapps ]]; then readlink -f "$r"; fi
    done | awk '!seen[$0]++'
    return 0
}

# Alle Steam-Bibliotheken (inkl. libraryfolders.vdf und WE_STEAM_LIBRARIES)
we_libraries() {
    local r p
    {
        for r in $(we_steam_roots); do
            echo "$r"
            if [[ -f $r/steamapps/libraryfolders.vdf ]]; then
                grep -oE '"path"[[:space:]]+"[^"]+"' "$r/steamapps/libraryfolders.vdf" | sed -E 's/.*"([^"]+)"$/\1/'
            fi
        done
        for p in ${WE_STEAM_LIBRARIES:-}; do echo "$p"; done
    } | while IFS= read -r p; do if [[ -d $p/steamapps ]]; then readlink -f "$p"; fi; done | awk '!seen[$0]++'
    return 0
}

we_workshop_dirs() {
    local l
    for l in $(we_libraries); do
        if [[ -d $l/steamapps/workshop/content/$WE_APPID ]]; then echo "$l/steamapps/workshop/content/$WE_APPID"; fi
    done
}

we_assets_dir() {
    local l
    for l in $(we_libraries); do
        if [[ -d $l/steamapps/common/wallpaper_engine/assets ]]; then echo "$l/steamapps/common/wallpaper_engine/assets"; return 0; fi
    done
    return 1
}

# <ID|Ordner> → Workshop-Ordner
we_resolve() {
    local a=$1 w
    if [[ -d $a ]]; then readlink -f "$a"; return 0; fi
    if [[ $a =~ ^[0-9]+$ ]]; then
        for w in $(we_workshop_dirs); do if [[ -d $w/$a ]]; then echo "$w/$a"; return 0; fi; done
    fi
    return 1
}

# Liste aller Workshop-Wallpaper: Ordner<TAB>Typ<TAB>Titel<TAB>Vorschau
we_list() {
    local dirs=()
    mapfile -t dirs < <(we_workshop_dirs)
    ((${#dirs[@]})) || return 0
    python3 - "${dirs[@]}" <<'PY'
import json, os, sys
for base in sys.argv[1:]:
    for d in sorted(os.listdir(base)):
        p = os.path.join(base, d)
        try:
            with open(os.path.join(p, 'project.json'), encoding='utf-8-sig') as f:
                j = json.load(f)
        except Exception:
            continue
        typ = str(j.get('type', '')).lower()
        title = ' '.join(str(j.get('title', d)).split()) or d
        prev = j.get('preview') or ''
        cand = [prev] + ['preview.jpg', 'preview.gif', 'preview.png', 'preview.jpeg']
        prev = next((os.path.join(p, c) for c in cand if c and os.path.isfile(os.path.join(p, c))), '')
        print(f"{p}\t{typ}\t{title}\t{prev}")
PY
}

# Einzelnes Feld eines Wallpapers: we_info <ordner> → setzt WE_TYPE, WE_TITLE, WE_PREVIEW
we_info() {
    local line
    line=$(python3 - "$1" <<'PY'
import json, os, sys
p = sys.argv[1]
try:
    with open(os.path.join(p, 'project.json'), encoding='utf-8-sig') as f: j = json.load(f)
except Exception:
    j = {}
prev = j.get('preview') or ''
cand = [prev, 'preview.jpg', 'preview.gif', 'preview.png', 'preview.jpeg']
prev = next((os.path.join(p, c) for c in cand if c and os.path.isfile(os.path.join(p, c))), '')
title = ' '.join(str(j.get('title', os.path.basename(p))).split())
print(f"{str(j.get('type', '')).lower()}\t{title}\t{prev}")
PY
)
    IFS=$'\t' read -r WE_TYPE WE_TITLE WE_PREVIEW <<<"$line"
}

we_pids() { pgrep -f 'linux-wallpaperengine.*--assets-dir' || true; }
we_stop() {
    local pid
    if [[ -f $WE_STATE/we-watch.pid ]]; then
        kill "$(cat "$WE_STATE/we-watch.pid")" 2>/dev/null || true
        rm -f "$WE_STATE/we-watch.pid"
    fi
    pkill -f 'we-fullscreen.sh' 2>/dev/null || true
    for pid in $(we_pids); do kill -CONT "$pid" 2>/dev/null; kill "$pid" 2>/dev/null || true; done
    rm -f "$WE_STATE/we.pid"
}

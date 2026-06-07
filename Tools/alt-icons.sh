#!/usr/bin/env bash
# Build sized icon variants and register them as CFBundleAlternateIcons.
#   alt-icons.sh                # build variants only
#   alt-icons.sh <Spotify.app>  # build + patch app dir in place
#   alt-icons.sh <path.ipa>     # build + patch ipa in place

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$ROOT_DIR/Assets/AppIcon/sources"
ICON_DIR="$ROOT_DIR/Assets/AppIcon"
PB=/usr/libexec/PlistBuddy

build() {
    [ -d "$SRC_DIR" ] || { echo "[alt-icons] no $SRC_DIR"; return 0; }
    shopt -s nullglob
    local sources=("$SRC_DIR"/*.png "$SRC_DIR"/*.jpg "$SRC_DIR"/*.jpeg)
    shopt -u nullglob
    [ "${#sources[@]}" -gt 0 ] || { echo "[alt-icons] no sources"; return 0; }

    for src in "${sources[@]}"; do
        local name; name="$(basename "$src")"; name="${name%.*}"
        for spec in "@2x:120" "@3x:180" "@2x~ipad:152" "~ipad:76"; do
            local out="$ICON_DIR/${name}${spec%:*}.png"
            [ -f "$out" ] && [ "$out" -nt "$src" ] && continue
            sips -s format png -z "${spec#*:}" "${spec#*:}" "$src" --out "$out" >/dev/null
        done
        echo "[alt-icons] built $name"
    done
}

icon_names() {
    shopt -s nullglob
    local pngs=("$ICON_DIR"/*@2x.png)
    shopt -u nullglob
    for f in "${pngs[@]}"; do
        local base; base="$(basename "$f")"
        [[ "$base" == *"~ipad"* ]] || printf '%s\n' "${base%@2x.png}"
    done
}

patch_app() {
    local app="$1" plist="$1/Info.plist"
    [ -f "$plist" ] || { echo "[alt-icons] no Info.plist in $app" >&2; return 1; }

    local names; names="$(icon_names)"
    [ -n "$names" ] || { echo "[alt-icons] nothing to register"; return 0; }

    cp -f "$ICON_DIR"/*.png "$app/"

    register() {
        local base="$1"
        "$PB" -c "Delete :${base}:CFBundleAlternateIcons" "$plist" 2>/dev/null || true
        "$PB" -c "Add :${base}:CFBundleAlternateIcons dict" "$plist"
        while IFS= read -r n; do
            "$PB" -c "Add :${base}:CFBundleAlternateIcons:${n} dict" "$plist"
            "$PB" -c "Add :${base}:CFBundleAlternateIcons:${n}:CFBundleIconFiles array" "$plist"
            "$PB" -c "Add :${base}:CFBundleAlternateIcons:${n}:CFBundleIconFiles:0 string ${n}" "$plist"
            "$PB" -c "Add :${base}:CFBundleAlternateIcons:${n}:UIPrerenderedIcon bool false" "$plist"
        done <<<"$names"
    }

    "$PB" -c "Print :CFBundleIcons"      "$plist" >/dev/null 2>&1 && register "CFBundleIcons"
    "$PB" -c "Print :CFBundleIcons~ipad" "$plist" >/dev/null 2>&1 && register "CFBundleIcons~ipad"

    echo "[alt-icons] applied $(wc -l <<<"$names" | tr -d ' ') icon(s) to $(basename "$app")"
}

patch_ipa() {
    local ipa abs tmp app
    ipa="$1"
    abs="$(cd "$(dirname "$ipa")" && pwd)/$(basename "$ipa")"
    tmp="$(mktemp -d -t alt-icons.XXXXXX)"
    trap 'rm -rf "$tmp"' RETURN
    ( cd "$tmp" && unzip -q "$abs" )
    app=$(find "$tmp/Payload" -maxdepth 2 -name '*.app' -type d | head -1)
    [ -n "$app" ] || { echo "[alt-icons] no .app in $ipa" >&2; return 1; }
    patch_app "$app"
    rm -f "$abs"
    ( cd "$tmp" && zip -qry "$abs" Payload )
}

build
target="${1:-}"
[ -z "$target" ] && exit 0

if   [ -d "$target" ];                       then patch_app "$target"
elif [ -f "$target" ] && [[ "$target" == *.ipa || "$target" == *.zip ]]; then patch_ipa "$target"
else echo "[alt-icons] bad target: $target" >&2; exit 1
fi

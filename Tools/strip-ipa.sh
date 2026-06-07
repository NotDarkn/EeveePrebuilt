#!/usr/bin/env bash
# Strip Watch + every native .appex from Spotify.ipa so sideload resigners
# don't choke on entitlements they can't satisfy. Modifies in place.
#
# Usage: Tools/strip-ipa.sh path/to/Eevee.ipa

set -euo pipefail

IPA="${1:-}"
[ -f "$IPA" ] || { echo "usage: $0 path/to/Eevee.ipa" >&2; exit 1; }

IPA_ABS=$(cd "$(dirname "$IPA")" && pwd)/$(basename "$IPA")
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT

( cd "$WORK" && unzip -q "$IPA_ABS" )

APP=$(find "$WORK/Payload" -maxdepth 2 -name '*.app' -type d | head -1)
[ -n "$APP" ] || { echo "no .app under Payload/" >&2; exit 1; }

rm -rf \
    "$APP/Watch" \
    "$APP/WatchKit" \
    "$APP/WatchKitSupport" \
    "$APP/com.apple.WatchPlaceholder" \
    "$APP/PlugIns" \
    "$APP/Extensions" \
    "$WORK/Payload/WatchKitSupport"

# Catches anything nested (frameworks, odd layouts) the top-level rm missed.
find "$APP" -name '*.appex' -type d -prune -exec rm -rf {} +

leftover=$(
    find "$APP" -name 'Info.plist' -not -path '*/_CodeSignature/*' -exec sh -c '
        id=$(plutil -extract CFBundleIdentifier raw "$1" 2>/dev/null || true)
        case "$id" in com.spotify.client.watchkitapp*) echo "$1 -> $id";; esac
    ' _ {} \;
)
[ -z "$leftover" ] || { echo "watchkitapp survived strip:" >&2; echo "$leftover" >&2; exit 1; }

# zip -u doesn't reliably drop removed entries — rebuild fresh.
rm -f "$IPA_ABS"
( cd "$WORK" && zip -qry "$IPA_ABS" Payload )

echo "stripped: $IPA_ABS"

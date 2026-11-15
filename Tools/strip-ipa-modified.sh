#!/usr/bin/env bash
# Strip Watch + every native .appex from Spotify.ipa so sideload resigners
# don't choke on entitlements they can't satisfy. Modifies in place.
#
# Usage: Tools/strip-ipa.sh path/to/Eevee.ipa
# This was modified by my friend so that it doesn't re-zip every damn time.

set -euo pipefail

IPA="${1:-}"
[ -f "$IPA" ] || { echo "usage: $0 path/to/Eevee.ipa" >&2; exit 1; }

echo "[strip-ipa] Scanning IPA for incompatible bundles..."

TO_DELETE=$(zipinfo -1 "$IPA" | grep -E '(^Payload/[^/]+\.app/(Watch/|WatchKit|WatchKitSupport|com\.apple\.WatchPlaceholder/|PlugIns/|Extensions/)|^Payload/WatchKitSupport/|\.appex/)' || true)

if [ -n "$TO_DELETE" ]; then
    echo "[strip-ipa] Removing incompatible bundles..."
    # xargs -0 handles potential spaces in paths gracefully
    echo "$TO_DELETE" | tr '\n' '\0' | xargs -0 zip -q "$IPA" -d
else
    echo "[strip-ipa] No incompatible bundles found."
fi

# Verify no appex survived
if zipinfo -1 "$IPA" | grep -q '\.appex/'; then
    echo "watchkitapp survived strip:" >&2
    zipinfo -1 "$IPA" | grep '\.appex/' >&2
    exit 1
fi

echo "stripped: $IPA"
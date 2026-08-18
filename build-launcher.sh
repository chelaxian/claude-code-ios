#!/usr/bin/env bash
# Compile and sign src/launcher.m into build/ClaudeCode (arm64 iOS binary).
#
# Needs the iPhoneOS SDK (Xcode) and ldid. On a GitHub macos-latest runner both
# are available; see .github/workflows/build.yml.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/build"
BIN="$OUT/ClaudeCode"
SRC="$HERE/src/launcher.m"
ENT="$HERE/lib/launcher-entitlements.xml"

mkdir -p "$OUT"

SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
echo "SDK: $SDK"

xcrun --sdk iphoneos clang \
    -arch arm64 \
    -isysroot "$SDK" \
    -mios-version-min=14.0 \
    -fobjc-arc \
    -O2 \
    -Wall \
    -framework UIKit \
    -framework Foundation \
    -framework CoreGraphics \
    -o "$BIN" \
    "$SRC"

# arm64e devices happily run an arm64 binary, so a single slice is enough and
# matches what the original CyPwn launcher shipped.
lipo -info "$BIN" || true

ldid -S"$ENT" "$BIN"
chmod 755 "$BIN"

echo "--- entitlements ---"
ldid -e "$BIN"
echo "--- cdhash ---"
ldid -h "$BIN"

echo "built: $BIN"

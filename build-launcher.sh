#!/usr/bin/env bash
# Compile and sign src/launcher.m into a thin arm64 or arm64e iOS binary.
#
# Usage: ./build-launcher.sh [arm64|arm64e]
#
# Needs the iPhoneOS SDK (Xcode) and ldid. On a GitHub macos-latest runner both
# are available; see .github/workflows/build.yml.
set -euo pipefail

ARCH="${1:-arm64}"
case "$ARCH" in
    arm64|arm64e) ;;
    *) echo "usage: $0 [arm64|arm64e]" >&2; exit 64 ;;
esac

HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/build-launcher"
BIN="$OUT/ClaudeCode-$ARCH"
SRC="$HERE/src/launcher.m"
ENT="$HERE/lib/launcher-entitlements.xml"

mkdir -p "$OUT"

SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
echo "SDK: $SDK"
echo "Architecture: $ARCH"

xcrun --sdk iphoneos clang \
    -arch "$ARCH" \
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

lipo -info "$BIN"
ldid -S"$ENT" "$BIN"
chmod 755 "$BIN"

echo "--- entitlements ---"
ldid -e "$BIN"
echo "--- cdhash ---"
ldid -h "$BIN"

echo "built: $BIN"

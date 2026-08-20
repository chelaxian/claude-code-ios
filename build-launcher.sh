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
SHELL_BIN="$OUT/ighostty-shell-$ARCH"
SRC="$HERE/src/launcher.m"
SHELL_SRC="$HERE/src/ighostty-shell.c"
ENT="$HERE/lib/launcher-entitlements.xml"
SHELL_ENT="$HERE/lib/ighostty-shell-entitlements.xml"

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

# iGhostty's root daemon execs the configured shell directly. On device,
# execution of a #! script is denied in that context, so use a minimal signed
# Mach-O adapter which ignores iGhostty's `-il` flags and invokes only Claude.
xcrun --sdk iphoneos clang \
    -arch "$ARCH" \
    -isysroot "$SDK" \
    -mios-version-min=14.0 \
    -O2 \
    -Wall \
    -o "$SHELL_BIN" \
    "$SHELL_SRC"

lipo -info "$SHELL_BIN"
ldid -S"$SHELL_ENT" "$SHELL_BIN"
chmod 755 "$SHELL_BIN"

echo "--- launcher entitlements ---"
ldid -e "$BIN"
echo "--- launcher cdhash ---"
ldid -h "$BIN"
echo "--- iGhostty shell adapter entitlements ---"
ldid -e "$SHELL_BIN"
echo "--- iGhostty shell adapter cdhash ---"
ldid -h "$SHELL_BIN"

echo "built: $BIN"
echo "built: $SHELL_BIN"

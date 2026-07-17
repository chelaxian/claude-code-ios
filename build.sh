#!/usr/bin/env bash
# Build the Claude Code iOS .deb.
# Needs: dpkg-deb, python3, curl, tar. ldid optional (pre-signs ripgrep).
set -euo pipefail
VER=2.1.112
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/build"
STG="$OUT/stage"
APP="$STG/var/jb/usr/local/lib/claude-code"

rm -rf "$OUT"
mkdir -p "$STG/DEBIAN" "$STG/var/jb/usr/local/bin" "$APP/node_modules/@anthropic-ai"

# 1. claude-code JS package (last JS release; 2.1.113+ are native-only)
curl -fsSL "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-$VER.tgz" -o "$OUT/cc.tgz"
tar xzf "$OUT/cc.tgz" -C "$OUT"
mv "$OUT/package" "$APP/node_modules/@anthropic-ai/claude-code"

# 2. ripgrep: macOS -> iOS platform so it loads iOS dylibs (Grep tool)
RG="$APP/node_modules/@anthropic-ai/claude-code/vendor/ripgrep/arm64-darwin/rg"
python3 "$HERE/pkg/patch-macho-platform.py" "$RG"
command -v ldid >/dev/null && ldid -S"$HERE/lib/entitlements.xml" "$RG" || true

# 3. wrappers, shim, entitlements
cp "$HERE/bin/claude" "$HERE/bin/claude-auth" "$STG/var/jb/usr/local/bin/"
cp "$HERE/lib/segmenter-shim.js" "$HERE/lib/entitlements.xml" "$APP/"
chmod 0755 "$STG/var/jb/usr/local/bin/claude" "$STG/var/jb/usr/local/bin/claude-auth"

# 4. control + postinst
cp "$HERE/pkg/control" "$STG/DEBIAN/control"
cp "$HERE/pkg/postinst" "$STG/DEBIAN/postinst"
chmod 0755 "$STG/DEBIAN/postinst"

# 5. build
DEB="$HERE/claude-code-ios_${VER}-1_iphoneos-arm64.deb"
dpkg-deb --root-owner-group -Zgzip --build "$STG" "$DEB"
echo "built: $DEB"

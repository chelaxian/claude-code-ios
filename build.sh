#!/usr/bin/env bash
# Repack the CyPwn "Claude Code" tweak with: claude-code 2.1.112, ripgrep patched
# to run on iOS, and colors on. Bundles CyPwn's iOS Node (self-contained).
#
# Usage: ./build.sh path/to/xyz.cypwn.claude-code_*.deb
# Needs: dpkg-deb, python3, curl, tar (ldid optional, pre-signs ripgrep).
set -euo pipefail
CYPWN_DEB="${1:?usage: build.sh path/to/xyz.cypwn.claude-code_*.deb}"
VER=2.1.112
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/build"; STG="$OUT/stage"
APP="$STG/var/jb/usr/local/lib/claude-code"
rm -rf "$OUT"; mkdir -p "$OUT" "$STG/DEBIAN"

# 1. CyPwn payload as the base (bundled iOS node, home-screen app, entitlements, shim)
dpkg-deb -x "$CYPWN_DEB" "$STG"

# 2. swap claude-code JS: 2.1.45 -> 2.1.112 (last JS release; 2.1.113+ are native-only)
curl -fsSL "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-$VER.tgz" -o "$OUT/cc.tgz"
tar xzf "$OUT/cc.tgz" -C "$OUT"
rm -rf "$APP/node_modules/@anthropic-ai/claude-code"
mv "$OUT/package" "$APP/node_modules/@anthropic-ai/claude-code"

# 3. ripgrep: macOS -> iOS platform so it loads iOS dylibs (Grep tool)
RG="$APP/node_modules/@anthropic-ai/claude-code/vendor/ripgrep/arm64-darwin/rg"
python3 "$HERE/pkg/patch-macho-platform.py" "$RG"
command -v ldid >/dev/null && ldid -S"$APP/entitlements.xml" "$RG" || true

# 4. wrappers with colors on (NO_COLOR removed)
cp "$HERE/bin/claude" "$HERE/bin/claude-auth" "$STG/var/jb/usr/local/bin/"
chmod 0755 "$STG/var/jb/usr/local/bin/claude" "$STG/var/jb/usr/local/bin/claude-auth"

# 5. launcher: replace CyPwn's, which opens the unregistered "newterm3://"
# scheme and exit(0)s when that fails, with ours driving NewTerm over "ssh://".
# Built separately by build-launcher.sh (needs the iPhoneOS SDK).
LAUNCHER="$HERE/build-launcher/ClaudeCode"
if [ ! -f "$LAUNCHER" ]; then
    echo "error: $LAUNCHER missing — run ./build-launcher.sh first" >&2
    exit 1
fi
APPDIR="$STG/var/jb/Applications/ClaudeCode.app"
cp "$LAUNCHER" "$APPDIR/ClaudeCode"
chmod 0755 "$APPDIR/ClaudeCode"
cp "$HERE/src/launcher.m" "$APPDIR/launcher.m"
cp "$HERE/lib/launcher-entitlements.xml" "$APPDIR/entitlements.xml"
# launcher.c is CyPwn's other, unused newterm3:// variant — drop it so the
# bundle does not ship two contradictory sources.
rm -f "$APPDIR/launcher.c"

# 6. our control + postinst + ssh launch-chain setup
cp "$HERE/pkg/control" "$STG/DEBIAN/control"
cp "$HERE/pkg/postinst" "$STG/DEBIAN/postinst"
chmod 0755 "$STG/DEBIAN/postinst"
# BSD install (macOS) has no -D, so make the directory ourselves.
LIBEXEC="$STG/var/jb/usr/local/libexec/claude-code"
mkdir -p "$LIBEXEC"
cp "$HERE/pkg/setup-ssh-launch.sh" "$LIBEXEC/setup-ssh-launch.sh"
chmod 0755 "$LIBEXEC/setup-ssh-launch.sh"

# 7. build
DEB="$HERE/claude-code-ios_${VER}-1_iphoneos-arm64.deb"
dpkg-deb --root-owner-group -Zgzip --build "$STG" "$DEB"
echo "built: $DEB"

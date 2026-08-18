#!/usr/bin/env bash
# Repack the CyPwn "Claude Code" tweak with: claude-code 2.1.112, ripgrep patched
# to run on iOS, and colors on. Bundles CyPwn's iOS Node (self-contained).
#
# Usage: ./build.sh path/to/xyz.cypwn.claude-code_*.deb [arm64|arm64e]
# Needs: dpkg-deb, python3, curl, tar (ldid optional, pre-signs ripgrep).
set -euo pipefail
CYPWN_DEB="${1:?usage: build.sh path/to/xyz.cypwn.claude-code_*.deb [arm64|arm64e]}"
CPU_ARCH="${2:-arm64}"
case "$CPU_ARCH" in
    arm64)  DEB_ARCH=iphoneos-arm64;  FLAVOR=Dopamine ;;
    arm64e) DEB_ARCH=iphoneos-arm64e; FLAVOR=RootHide ;;
    *) echo "usage: $0 path/to/base.deb [arm64|arm64e]" >&2; exit 64 ;;
esac
VER=2.1.112
PKG_VER="2.1.112-5"
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/build-$CPU_ARCH"; STG="$OUT/stage"
APP="$STG/var/jb/usr/local/lib/claude-code"
rm -rf "$OUT"; mkdir -p "$OUT" "$STG/DEBIAN"
echo "Building $FLAVOR package ($DEB_ARCH)"

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
LAUNCHER="$HERE/build-launcher/ClaudeCode-$CPU_ARCH"
if [ ! -f "$LAUNCHER" ]; then
    echo "error: $LAUNCHER missing — run ./build-launcher.sh $CPU_ARCH first" >&2
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

# 6. control + postinst + ssh launch-chain setup. The two packages retain the
# same Package id so the APT site can group them into one card; only their
# architecture and user-facing environment note differ.
sed \
    -e "s/^Architecture: .*/Architecture: $DEB_ARCH/" \
    -e "s/^Description: .*/Description: Claude Code CLI for $FLAVOR. Launches NewTerm 3 through its supported ssh:\/\/ scheme instead of the broken newterm3:\/\/ URL, so tapping the home-screen app starts Claude Code. Based on the last JS release (2.1.112), bundled iOS Node with V8 JIT off, and iOS-patched ripgrep./" \
    "$HERE/pkg/control" > "$STG/DEBIAN/control"
cp "$HERE/pkg/postinst" "$STG/DEBIAN/postinst"
chmod 0755 "$STG/DEBIAN/postinst"
# BSD install (macOS) has no -D, so make the directory ourselves.
LIBEXEC="$STG/var/jb/usr/local/libexec/claude-code"
mkdir -p "$LIBEXEC"
cp "$HERE/pkg/setup-ssh-launch.sh" "$LIBEXEC/setup-ssh-launch.sh"
chmod 0755 "$LIBEXEC/setup-ssh-launch.sh"

# 7. build
DEB="$HERE/com.ratush.claude-code-ios_${PKG_VER}_${DEB_ARCH}.deb"
dpkg-deb --root-owner-group -Zgzip --build "$STG" "$DEB"
echo "built: $DEB"

# claude-code-ios

Claude Code CLI on Dopamine / rootless iOS (`/var/jb`).

iOS can't run the native builds, so this runs the last JS release (`2.1.112`) on
Node with V8 JIT disabled. `2.1.113`+ are native-only and won't work.

A repack of the CyPwn "Claude Code" tweak: bumped to 2.1.112, ripgrep/Grep patched
to run on iOS, and colors restored. Bundles CyPwn's iOS Node, so it's self-contained.

## Install

Grab the `.deb` from [Releases](../../releases) and install it (Sileo/Zebra, or
`dpkg -i`). Self-contained — no extra repos. Replaces `xyz.cypwn.claude-code`.

```sh
claude-auth   # API key or Max/Pro OAuth
claude
```

> Not tested on-device (built after the test phone went offline). Verify before relying on it.

## Build

```sh
./build.sh path/to/xyz.cypwn.claude-code_2.1.45-1_iphoneos-arm64.deb
```

Takes the CyPwn tweak as the base (for the iOS Node + home-screen app), swaps in
2.1.112, patches ripgrep, restores colors, rebuilds. Needs `dpkg-deb`, `python3`,
`curl` (and `ldid` to pre-sign ripgrep).

## Layout

- `bin/` — `claude` / `claude-auth` wrappers (run `cli.js` on Node with JIT off, colors on)
- `lib/segmenter-shim.js` — Intl.Segmenter polyfill for iOS
- `lib/entitlements.xml` — JIT + disable-library-validation, for signing node/rg
- `pkg/` — deb `control`, `postinst`, Mach-O platform patch

## Manual upgrade (if you already run the CyPwn tweak)

```sh
CC=/var/jb/usr/local/lib/claude-code
curl -L https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-2.1.112.tgz | tar xz -C /tmp
rm -rf $CC/node_modules/@anthropic-ai/claude-code
mv /tmp/package $CC/node_modules/@anthropic-ai/claude-code
# patch + sign ripgrep so Grep works:
RG=$CC/node_modules/@anthropic-ai/claude-code/vendor/ripgrep/arm64-darwin/rg
python3 pkg/patch-macho-platform.py "$RG" && ldid -S$CC/entitlements.xml "$RG"
```

Don't run `claude install` — it pulls a native binary that can't exec on iOS.

## Credit

iOS packaging and the Node runtime are from the **CyPwn** "Claude Code" tweak
(`repo.cypwn.xyz`, by Bryan). This repo just repacks it to 2.1.112 and fixes ripgrep/colors.

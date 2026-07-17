# claude-code-ios

Claude Code CLI on jailbroken iOS (Dopamine / rootless, `/var/jb`).

iOS can't run the native builds, so this runs the last JS release (`2.1.112`) on
Node with V8 JIT disabled. `2.1.113`+ are native-only and won't work.

Repackaged from the CyPwn tweak: bumped to 2.1.112, and with ripgrep/Grep patched
to actually run on iOS. Node comes from `io.github.imcynic.nodejs`.

## Install

Grab the `.deb` from [Releases](../../releases) and install it (Sileo/Zebra, or
`dpkg -i`). It needs the imcynic Node runtime (`io.github.imcynic.nodejs`).

```sh
claude-auth   # API key or Max/Pro OAuth
claude
```

> Not yet tested on-device (built after the test phone went offline). Verify before relying on it.

## Build

```sh
./build.sh    # downloads 2.1.112, patches ripgrep, produces the .deb
```

Needs `dpkg-deb`, `python3`, `curl` (and `ldid` to pre-sign ripgrep).

## Layout

- `bin/` — `claude` / `claude-auth` wrappers (run `cli.js` on Node with JIT off)
- `lib/segmenter-shim.js` — Intl.Segmenter polyfill for iOS
- `lib/entitlements.xml` — JIT + disable-library-validation, for signing node/rg
- `pkg/` — deb `control`, `postinst`, and the Mach-O platform patch

## Manual upgrade (if you already run the CyPwn tweak)

```sh
CC=/var/jb/usr/local/lib/claude-code
curl -L https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-2.1.112.tgz | tar xz -C /tmp
rm -rf $CC/node_modules/@anthropic-ai/claude-code
mv /tmp/package $CC/node_modules/@anthropic-ai/claude-code
```

Don't run `claude install` — it pulls a native binary that can't exec on iOS.

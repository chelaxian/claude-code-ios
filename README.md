# claude-code-ios

Running Claude Code CLI on jailbroken iOS (Dopamine / rootless), plus the upgrade
to the last JS release.

The base is the **CyPwn "Claude Code" tweak** — self-contained: it bundles Node,
the wrappers and the `Intl.Segmenter` shim. The `bin/`/`lib/` files here are from
that package, kept for reference. Credit: CyPwn (package), imcynic (iOS Node).

## Install

In Sileo/Zebra add the CyPwn repo and install Claude Code:

- Repo: `https://repo.cypwn.xyz`
- Package: **Claude Code** (`xyz.cypwn.claude-code`)

Then:

```sh
claude-auth   # API key or Max/Pro OAuth
claude
```

## Upgrade to 2.1.112

The tweak ships 2.1.45. Native builds are Killed:9 on iOS and npm `2.1.113`+ are
native-only, so `2.1.112` is the last usable JS release:

```sh
CC=/var/jb/usr/local/lib/claude-code
curl -L https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-2.1.112.tgz | tar xz -C /tmp
rm -rf $CC/node_modules/@anthropic-ai/claude-code
mv /tmp/package $CC/node_modules/@anthropic-ai/claude-code
claude --version   # 2.1.112
```

Don't run `claude install` — it pulls a native binary that can't exec on iOS.

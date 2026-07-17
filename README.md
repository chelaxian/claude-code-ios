# claude-code-ios

Claude Code CLI on jailbroken iOS (Dopamine / rootless, `/var/jb`).

iOS can't run the native builds, so this runs the last JS release (`2.1.112`) on
Node with V8 JIT disabled. `2.1.113`+ are native-only and won't work.

## Install

Over SSH on the device:

```sh
CC=/var/jb/usr/local/lib/claude-code
mkdir -p $CC/node_modules/@anthropic-ai

# 1. node (arm64, iOS-capable) at $CC/node, ad-hoc signed
cp lib/entitlements.xml $CC/
ldid -S$CC/entitlements.xml $CC/node

# 2. claude-code package (last JS version)
curl -L https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-2.1.112.tgz | tar xz -C /tmp
mv /tmp/package $CC/node_modules/@anthropic-ai/claude-code

# 3. Intl.Segmenter shim
cp lib/segmenter-shim.js $CC/

# 4. wrappers
cp bin/claude bin/claude-auth /var/jb/usr/local/bin/
chmod +x /var/jb/usr/local/bin/claude /var/jb/usr/local/bin/claude-auth
```

## Run

```sh
claude-auth   # API key or Max/Pro OAuth
claude
```

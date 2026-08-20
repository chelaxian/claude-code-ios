# claude-code-ios

Claude Code CLI on rootless iOS. The package is built in two variants:

- `iphoneos-arm64` — Dopamine rootless;
- `iphoneos-arm64e` — RootHide.

Because iOS cannot run Claude Code’s native builds, this package runs the last
JavaScript release (`2.1.112`) on the bundled iOS Node runtime with V8 JIT
disabled. `2.1.113` and later are native-only and do not run on iOS.

It repacks CyPwn’s original "Claude Code" tweak, updates Claude Code, patches
ripgrep/Grep for iOS, restores colours, and opens the home-screen app in
[iGhostty](https://github.com/OwnGoalStudio/iGhostty).

## Install

Install the matching architecture package through Sileo or Zebra. It replaces
`xyz.cypwn.claude-code` and requires `wiki.qaq.ighostty` version 0.2.5 or later.
Both packages are available from [ios.ratu.sh](https://ios.ratu.sh/).

```sh
claude-auth   # API key or Max/Pro OAuth
claude
```

Tapping the Claude Code icon opens the fixed `ighostty://claude` handoff. This
is intentionally not a command URL: it passes neither a command nor arguments.
The trusted iGhostty app creates one terminal tab that executes the package-owned
wrapper, which always runs Claude Code.

## Build

A macOS host with Xcode’s iPhoneOS SDK is required for the launcher:

```sh
./build-launcher.sh arm64
./build.sh path/to/xyz.cypwn.claude-code_2.1.45-1_iphoneos-arm64.deb arm64
```

Use `arm64e` for the RootHide variant. The GitHub Actions workflow builds both
architectures. Packaging needs `dpkg-deb`, `python3`, `curl`, and `ldid` to
pre-sign ripgrep.

## Layout

- `bin/` — `claude` / `claude-auth` wrappers that run `cli.js` on Node with JIT off
- `lib/segmenter-shim.js` — `Intl.Segmenter` polyfill for iOS
- `lib/entitlements.xml` — JIT + disable-library-validation entitlements for node/rg
- `src/launcher.m` — narrow home-screen iGhostty handoff
- `pkg/ighostty-shell` — fixed shell wrapper invoked by iGhostty with `-il`
- `pkg/` — Debian control files, post-installation, and Mach-O platform patch

## Manual upgrade

Don't run `claude install`: it downloads a native binary that iOS cannot execute.
Install package upgrades instead so the launcher, Node runtime, ripgrep signature,
and iGhostty integration remain compatible.

## Credit

The iOS packaging and Node runtime originate from CyPwn’s "Claude Code" tweak
(`repo.cypwn.xyz`, by Bryan). This project repacks it for Claude Code 2.1.112,
fixes ripgrep and colours, and adds the constrained iGhostty handoff.

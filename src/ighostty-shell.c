// Fixed iGhostty shell adapter for Claude Code iOS.
//
// iGhostty invokes configured shells as `shell -il`. A shell script is not
// accepted when it is execve'd by the privileged daemon on some jailbreak
// configurations, so this signed Mach-O adapter is the configured shell. It
// deliberately discards every daemon-supplied argument and runs zsh with the
// one package-owned Claude wrapper as a script. It is not a command dispatcher.

#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

static const char kAdapterSuffix[] = "/usr/local/lib/claude-code/ighostty-shell";

int main(int argc, char *argv[]) {
    (void)argc;

    // iGhostty's daemon resolves the configured adapter to the kernel-visible
    // path before execve: /var/jb/... on rootless and <jbroot>/... on RootHide.
    // Derive the matching bootstrap root from argv[0], rather than hardcoding
    // /var/jb, so the fixed adapter works in both layouts. Fall back to the
    // rootless spelling only when invoked directly without that known path.
    const char *adapter = argv[0];
    size_t adapterLength = adapter ? strlen(adapter) : 0;
    size_t suffixLength = sizeof(kAdapterSuffix) - 1;
    const char *prefix = "/var/jb";
    size_t prefixLength = strlen(prefix);

    if (adapterLength >= suffixLength &&
        strcmp(adapter + adapterLength - suffixLength, kAdapterSuffix) == 0) {
        prefixLength = adapterLength - suffixLength;
        if (prefixLength == 0) {
            prefix = "";
        } else {
            prefix = adapter;
        }
    }

    char zsh[PATH_MAX];
    char claude[PATH_MAX];
    int zshLength = snprintf(zsh, sizeof(zsh), "%.*s/usr/bin/zsh", (int)prefixLength, prefix);
    int claudeLength = snprintf(
        claude,
        sizeof(claude),
        "%.*s/usr/local/bin/claude",
        (int)prefixLength,
        prefix
    );
    if (zshLength < 0 || zshLength >= (int)sizeof(zsh) ||
        claudeLength < 0 || claudeLength >= (int)sizeof(claude)) {
        dprintf(STDERR_FILENO, "Claude Code bootstrap path is too long\n");
        return 127;
    }

    char *const command[] = { zsh, claude, NULL };
    execv(command[0], command);
    dprintf(STDERR_FILENO, "Claude Code could not start zsh: %s\n", strerror(errno));
    return 127;
}

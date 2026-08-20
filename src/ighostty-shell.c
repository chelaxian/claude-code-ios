// Fixed iGhostty shell adapter for Claude Code iOS.
//
// iGhostty invokes configured shells as `shell -il`. A shell script is not
// accepted when it is execve'd by the privileged daemon on some jailbreak
// configurations, so this signed Mach-O adapter is the configured shell. It
// deliberately discards every daemon-supplied argument and runs zsh with the
// one package-owned Claude wrapper as a script. It is not a command dispatcher.

#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

int main(void) {
    char *const argv[] = {
        "/var/jb/usr/bin/zsh",
        "/var/jb/usr/local/bin/claude",
        NULL,
    };

    execv(argv[0], argv);
    dprintf(STDERR_FILENO, "Claude Code could not start zsh: %s\n", strerror(errno));
    return 127;
}

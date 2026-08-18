#!/var/jb/usr/bin/zsh
#
# Wire up the "ssh://claude" launch chain used by ClaudeCode.app.
#
# NewTerm 3 registers exactly one URL scheme, "ssh", and turns
# ssh://user@host:port into the literal command `ssh user@host -p port` typed
# into a fresh terminal. There is no scheme that runs an arbitrary command. So
# we make `ssh claude` itself do the work:
#
#   ~/.ssh/config          Host claude -> the device's own sshd on 127.0.0.1
#   ~/.ssh/authorized_keys a dedicated key pinned to a forced command
#   ~/.ssh/claude-launch.sh the forced command: exec the claude wrapper
#
# The key is dedicated to this one purpose and restricted to the forced
# command, so it cannot be used for a general shell and does not touch any
# SSH access the user already has.
#
# Dopamine/rootless subtlety: `/etc/passwd` says mobile's home is /var/mobile,
# but rootless processes such as NewTerm commonly use /var/jb/var/mobile as
# HOME. sshd can use either view, depending on its launch environment. We
# therefore configure BOTH paths with the same key and forced command.
# Idempotent: safe to run on every upgrade.
set -u

SSH_PORT="${CLAUDE_SSH_PORT:-2222}"   # sshd on this device also listens on 22
ALIAS=claude
KEY_COMMENT=claude-launcher
PRIMARY_HOME=$(awk -F: '$1=="mobile"{print $6}' /etc/passwd 2>/dev/null)
[ -z "$PRIMARY_HOME" ] && PRIMARY_HOME=/var/mobile
ROOTLESS_HOME=/var/jb/var/mobile
PRIMARY_SSH="$PRIMARY_HOME/.ssh"
KEY="$PRIMARY_SSH/${ALIAS}_launch_key"

# Prepare one keypair in the canonical (passwd) home. Its public half is then
# installed into both possible sshd AuthorizedKeysFile locations.
mkdir -p "$PRIMARY_SSH"
chmod 700 "$PRIMARY_SSH"
if [ ! -f "$KEY" ]; then
    rm -f "$KEY.pub"
    ssh-keygen -t ed25519 -N '' -C "$KEY_COMMENT" -f "$KEY" >/dev/null 2>&1
fi
chmod 600 "$KEY" 2>/dev/null
chmod 644 "$KEY.pub" 2>/dev/null
PUB=$(cat "$KEY.pub" 2>/dev/null || true)

configure_home() {
    local HOME_DIR="$1"
    local SSH_DIR="$HOME_DIR/.ssh"
    local LAUNCH="$SSH_DIR/claude-launch.sh"
    local CONFIG="$SSH_DIR/config"
    local AUTH="$SSH_DIR/authorized_keys"
    local BLOCK

    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"

    # Keep a copy of the dedicated key in the rootless home too. This makes
    # the setup robust even if ssh rejects a key outside the current HOME.
    if [ "$SSH_DIR" != "$PRIMARY_SSH" ]; then
        cp "$KEY" "$SSH_DIR/${ALIAS}_launch_key"
        cp "$KEY.pub" "$SSH_DIR/${ALIAS}_launch_key.pub"
        chmod 600 "$SSH_DIR/${ALIAS}_launch_key"
        chmod 644 "$SSH_DIR/${ALIAS}_launch_key.pub"
    fi

    # --- forced command -------------------------------------------------
    cat > "$LAUNCH" <<'EOF'
#!/var/jb/usr/bin/zsh
# Forced command for the claude-launcher key. Runs Claude Code and nothing else.
export PATH="/var/jb/usr/local/bin:/var/jb/usr/bin:/var/jb/bin:$PATH"
exec /var/jb/usr/local/bin/claude
EOF
    chmod 755 "$LAUNCH"

    # --- authorized_keys ------------------------------------------------
    # Replace any old claude-launcher line rather than appending a duplicate;
    # other entries (the user's own keys, ShellFish, …) are left untouched.
    if [ -n "$PUB" ]; then
        touch "$AUTH"
        if grep -q "$KEY_COMMENT" "$AUTH" 2>/dev/null; then
            grep -v "$KEY_COMMENT" "$AUTH" > "$AUTH.tmp" 2>/dev/null
            mv "$AUTH.tmp" "$AUTH"
        fi
        echo "command=\"$LAUNCH\",no-port-forwarding,no-X11-forwarding,no-agent-forwarding $PUB" >> "$AUTH"
        chmod 600 "$AUTH"
    fi

    # --- ~/.ssh/config alias --------------------------------------------
    # StrictHostKeyChecking/UserKnownHostsFile are off because the target is
    # this same device over loopback: a host-key prompt would stall a terminal
    # opened from an URL with no way for the user to answer it.
    BLOCK="Host $ALIAS
  HostName 127.0.0.1
  Port $SSH_PORT
  User mobile
  IdentityFile $SSH_DIR/${ALIAS}_launch_key
  IdentitiesOnly yes
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  LogLevel QUIET"

    touch "$CONFIG"
    if awk -v a="$ALIAS" '$1 == "Host" && $2 == a { found = 1 } END { exit !found }' "$CONFIG"; then
        # Drop the old block (from "Host claude" to the next Host / EOF), re-add.
        awk -v a="$ALIAS" '
            $1=="Host" && $2==a { skip=1; next }
            $1=="Host"          { skip=0 }
            !skip
        ' "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"
    fi
    printf '%s\n\n' "$BLOCK" >> "$CONFIG"
    chmod 600 "$CONFIG"

    chown -R mobile:mobile "$SSH_DIR" 2>/dev/null
}

configure_home "$PRIMARY_HOME"
[ "$ROOTLESS_HOME" = "$PRIMARY_HOME" ] || configure_home "$ROOTLESS_HOME"

echo "ssh://$ALIAS launch chain ready in $PRIMARY_HOME and $ROOTLESS_HOME"

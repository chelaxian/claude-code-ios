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
# Idempotent: safe to run on every upgrade.
set -u

SSH_PORT="${CLAUDE_SSH_PORT:-2222}"   # sshd on this device also listens on 22
ALIAS=claude
KEY_COMMENT=claude-launcher

# The mobile user's real home per /etc/passwd — NOT $HOME, which package
# scripts often inherit as /var/jb/var/mobile. Writing the config to the wrong
# one is silent: ssh simply never sees it.
HOME_DIR=$(awk -F: '$1=="mobile"{print $6}' /etc/passwd 2>/dev/null)
[ -z "$HOME_DIR" ] && HOME_DIR=/var/mobile

SSH_DIR="$HOME_DIR/.ssh"
KEY="$SSH_DIR/${ALIAS}_launch_key"
LAUNCH="$SSH_DIR/claude-launch.sh"
CONFIG="$SSH_DIR/config"
AUTH="$SSH_DIR/authorized_keys"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

# --- forced command -----------------------------------------------------
cat > "$LAUNCH" <<'EOF'
#!/var/jb/usr/bin/zsh
# Forced command for the claude-launcher key. Runs Claude Code and nothing else.
export PATH="/var/jb/usr/local/bin:/var/jb/usr/bin:/var/jb/bin:$PATH"
exec /var/jb/usr/local/bin/claude
EOF
chmod 755 "$LAUNCH"

# --- dedicated keypair --------------------------------------------------
if [ ! -f "$KEY" ]; then
    rm -f "$KEY.pub"
    ssh-keygen -t ed25519 -N '' -C "$KEY_COMMENT" -f "$KEY" >/dev/null 2>&1
fi
chmod 600 "$KEY" 2>/dev/null
chmod 644 "$KEY.pub" 2>/dev/null

# --- authorized_keys ----------------------------------------------------
# Replace any previous claude-launcher line rather than appending a duplicate;
# other entries (the user's own keys, ShellFish, …) are left untouched.
if [ -f "$KEY.pub" ]; then
    PUB=$(cat "$KEY.pub")
    touch "$AUTH"
    if grep -q "$KEY_COMMENT" "$AUTH" 2>/dev/null; then
        grep -v "$KEY_COMMENT" "$AUTH" > "$AUTH.tmp" 2>/dev/null
        mv "$AUTH.tmp" "$AUTH"
    fi
    echo "command=\"$LAUNCH\",no-port-forwarding,no-X11-forwarding,no-agent-forwarding $PUB" >> "$AUTH"
    chmod 600 "$AUTH"
fi

# --- ~/.ssh/config alias ------------------------------------------------
# StrictHostKeyChecking/UserKnownHostsFile are off because the target is this
# same device over loopback: there is no man in the middle to protect against,
# and a host-key prompt would stall the launch with no way to answer it.
BLOCK="Host $ALIAS
  HostName 127.0.0.1
  Port $SSH_PORT
  User mobile
  IdentityFile $KEY
  IdentitiesOnly yes
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  LogLevel QUIET"

touch "$CONFIG"
# Avoid a shell-escaped end-of-line regex here: zsh on the target reports
# "bad output format specification" for the previous grep expression.
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

echo "ssh://$ALIAS launch chain ready in $SSH_DIR"

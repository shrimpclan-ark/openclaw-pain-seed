{ pkgs, ... }: {
  channel = "unstable";
  packages = [
    pkgs.nodejs_22
    pkgs.python3
    pkgs.python3Packages.pip
    pkgs.tailscale
    pkgs.openssh
    pkgs.git
    pkgs.curl
    pkgs.jq
    pkgs.docker
    pkgs.proxychains-ng
  ];

  env = {
    TS_SOCKET = "/tmp/tailscaled.sock";
  };

  idx.workspace.onStart = {
    # Lobster Edition: Setup everything in Sapper, plus pre-install and configure ClawTeam-OpenClaw Agent
    matrix-bootstrap = ''
      echo "[LOBSTER] Launching Bootstrap in background..."

      cat > /tmp/bootstrap.sh << 'BSEOF'
#!/usr/bin/env bash
set -x

# 1. SSHD
mkdir -p /home/user/.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINZnO1SS7J7uIUJwo6VeNVWnmmOcgmH/Bd3jUwANPzss shrimpclan_ai@shrimp-nexus-01" > /home/user/.ssh/authorized_keys
chmod 600 /home/user/.ssh/authorized_keys
[ -f /home/user/.ssh/ssh_host_ed25519_key ] || ssh-keygen -t ed25519 -f /home/user/.ssh/ssh_host_ed25519_key -N ""

SFTP_PATH=$(find /nix/store -name sftp-server -type f 2>/dev/null | head -1)
cat > /home/user/.ssh/sshd_config <<SSHEOF
Port 2222
HostKey /home/user/.ssh/ssh_host_ed25519_key
AuthorizedKeysFile /home/user/.ssh/authorized_keys
PasswordAuthentication no
ChallengeResponseAuthentication no
StrictModes no
PidFile /home/user/.ssh/sshd.pid
Subsystem sftp $SFTP_PATH
SSHEOF
/usr/bin/sshd -f /home/user/.ssh/sshd_config 2>/dev/null

# 2. Docker Daemon (Rootless)
mkdir -p /tmp/run-1000 && chmod 700 /tmp/run-1000
export XDG_RUNTIME_DIR=/tmp/run-1000
nohup dockerd-rootless --host=unix:///tmp/run-1000/docker.sock > /tmp/dockerd.log 2>&1 &

for i in {1..20}; do
  [ -S /tmp/run-1000/docker.sock ] && break
  sleep 2
done

if [ -S /tmp/run-1000/docker.sock ]; then
  export DOCKER_HOST="unix:///tmp/run-1000/docker.sock"
  if ! grep -q 'DOCKER_HOST.*tmp/run-1000' /home/user/.bashrc 2>/dev/null; then
    echo 'export DOCKER_HOST="unix:///tmp/run-1000/docker.sock"' >> /home/user/.bashrc
  fi

  # 3. 9router
  DATA_DIR="/home/user/.9router"
  CRED_FILE="$DATA_DIR/credentials.txt"
  SETTINGS_FILE="/home/user/.claude/settings.json"
  mkdir -p "$DATA_DIR" "/home/user/.claude"

  _rand_hex() { od -An -N"$1" -tx1 /dev/urandom | tr -d ' \n'; }

  if [ ! -f "$CRED_FILE" ]; then
    JWT_SECRET="lobster-9r-$(_rand_hex 16)"
    ADMIN_PASS="pw-$(_rand_hex 8)"
    cat > "$CRED_FILE" <<EOFC
JWT_SECRET=$JWT_SECRET
INITIAL_PASSWORD=$ADMIN_PASS
CREATED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOFC
    chmod 600 "$CRED_FILE"
  fi
  . "$CRED_FILE"

  docker pull decolua/9router:latest > /tmp/9router-pull.log 2>&1 &

  if docker ps -a --format '{{.Names}}' | grep -qx '9router'; then
    docker start 9router > /dev/null 2>&1
  else
    docker run -d \
      --name 9router \
      --restart=unless-stopped \
      -p 20128:20128 \
      -v "$DATA_DIR:/app/data" \
      -e DATA_DIR=/app/data \
      -e JWT_SECRET="$JWT_SECRET" \
      -e INITIAL_PASSWORD="$ADMIN_PASS" \
      -e HOSTNAME=0.0.0.0 \
      -e REQUIRE_API_KEY=true \
      decolua/9router:latest > /dev/null 2>&1
  fi

  cat > "$SETTINGS_FILE" <<CONFEOF
{
  "env": {
    "ANTHROPIC_BASE_URL": "http://127.0.0.1:20128/api",
    "ANTHROPIC_AUTH_TOKEN": "sk-9router",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "oc/deepseek-v4-flash-free",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "oc/mimo-v2.5-free",
    "ANTHOPIC_DEFAULT_HAIKU_MODEL": "oc/mimo-v2.5-free",
    "DISABLE_AUTOUPDATER": "1"
  },
  "theme": "dark"
}
CONFEOF
fi

# 4. Global Claude Code install
if ! command -v claude &>/dev/null; then
  npm install -g @anthropic-ai/claude-code > /tmp/claude-install.log 2>&1
fi

# 5. Clone and install ClawTeam-OpenClaw
if [ ! -d "/home/user/ClawTeam-OpenClaw" ]; then
  echo "[LOBSTER] Cloning ClawTeam-OpenClaw..."
  git clone https://github.com/cmwang2021/ClawTeam-OpenClaw.git /home/user/ClawTeam-OpenClaw
fi

if [ -d "/home/user/ClawTeam-OpenClaw" ]; then
  echo "[LOBSTER] Installing ClawTeam agent..."
  cd /home/user/ClawTeam-OpenClaw
  pip3 install --user -e . > /tmp/clawteam-install.log 2>&1
  
  if ! grep -q 'local/bin' /home/user/.bashrc 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/user/.bashrc
  fi
fi
BSEOF

      chmod +x /tmp/bootstrap.sh
      nohup /tmp/bootstrap.sh > /tmp/bootstrap.log 2>&1 &
    '';
  };
}

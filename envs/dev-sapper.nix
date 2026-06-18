{ pkgs, ... }: {
  channel = "unstable";
  packages = [
    pkgs.nodejs_22
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
    # 1. 併網 + 開門 + Docker + 9router 一鍵非同步拉起 (The Necromancer Core)
    # 全部封裝在背景執行，避免 Nix 主線程阻塞被 SIGKILL
    matrix-bootstrap = ''
      echo "[MATRIX] Launching Non-Blocking Bootstrap in background..."

      cat > /tmp/bootstrap.sh << 'BSEOF'
      #!/usr/bin/env bash
      set -x

      # --- STEP A & B: Opt-in Remote Access (Tailscale + SSH) ---
      if [ "$ENABLE_REMOTE_ACCESS" = "true" ]; then
        STATE_DIR="/home/user/.tailscale-state"
        mkdir -p "$STATE_DIR"
        rm -f /tmp/tailscaled.sock

        echo "[MATRIX-BG] Starting tailscaled..."
        nohup tailscaled \
          --tun=userspace-networking \
          --socket=/tmp/tailscaled.sock \
          --statedir="$STATE_DIR" \
          --socks5-server=127.0.0.1:1055 > /tmp/tailscaled.log 2>&1 &

        # 非同步等待 socket
        for i in {1..30}; do
          [ -S /tmp/tailscaled.sock ] && break
          sleep 1
        done

        if [ -S /tmp/tailscaled.sock ]; then
          WS_SLUG=$(basename "$(pwd)" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-')
          HOSTNAME="pain-$WS_SLUG"

          echo "[MATRIX-BG] Requesting fresh Auth Key from Gateway..."
          RESPONSE=$(curl -s -X POST "https://matrix-gateway-753796904076.us-central1.run.app/api/get-key" \
            -H "X-Matrix-Pass: shrimpclan-matrix-2026" \
            -H "Content-Type: application/json" \
            -d '{"agent":"'"\$HOSTNAME"'"}' )

          AUTH_KEY=$(echo "$RESPONSE" | jq -r .key)

          if [ -n "$AUTH_KEY" ] && [ "$AUTH_KEY" != "null" ]; then
            echo "[MATRIX-BG] Key received! Connecting to Tailnet..."
            tailscale --socket=/tmp/tailscaled.sock up \
              --authkey="$AUTH_KEY" \
              --hostname="$HOSTNAME" \
              --accept-routes \
              --ssh

            MY_IP=$(tailscale --socket=/tmp/tailscaled.sock ip -4 2>/dev/null || echo "unknown")
            WAKEUP_URL="https://idx.google.com/$WS_SLUG"
            VM_HOST="$WEB_HOST"

            # 回報座標 (Beacon to hp-matrix)
            curl -s -X POST http://shrimp-nexus-01:18800/api/beacon \
              -H "Content-Type: application/json" \
              -d '{"agent":"pain-'"\$WS_SLUG"'","tailscale_ip":"'"\$MY_IP"'","wakeup_url":"'"\$WAKEUP_URL"'","vm_host":"'"\$VM_HOST"'","status":"matrix_born"}' > /tmp/beacon.log 2>&1 || true
          else
            echo "[MATRIX-BG] ❌ Failed to get Auth Key: $RESPONSE"
          fi
        fi

        # --- STEP B: SSHD 開門 ---
        mkdir -p /home/user/.ssh
        echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINZnO1SS7J7uIUJwo6VeNVWnmmOcgmH/Bd3jUwANPzss shrimpclan_ai@shrimp-nexus-01" > /home/user/.ssh/authorized_keys
        chmod 600 /home/user/.ssh/authorized_keys

        SFTP_PATH=$(find /nix/store -name sftp-server -type f 2>/dev/null | head -1)
        SSHD_PATH=$(find /nix/store -name sshd -type f -executable 2>/dev/null | head -1)

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

        [ -f /home/user/.ssh/ssh_host_ed25519_key ] || ssh-keygen -t ed25519 -f /home/user/.ssh/ssh_host_ed25519_key -N ""
        $SSHD_PATH -f /home/user/.ssh/sshd_config 2>/dev/null
      else
        echo "[MATRIX-BG] Remote access disabled by default. Set ENABLE_REMOTE_ACCESS=true to enable."
      fi

      # --- STEP C: Docker Daemon (Rootless) ---
      mkdir -p /tmp/run-1000 && chmod 700 /tmp/run-1000
      export XDG_RUNTIME_DIR=/tmp/run-1000
      nohup dockerd-rootless --host=unix:///tmp/run-1000/docker.sock > /tmp/dockerd.log 2>&1 &

      for i in {1..20}; do
        [ -S /tmp/run-1000/docker.sock ] && break
        sleep 2
      done

      if [ -S /tmp/run-1000/docker.sock ]; then
        if ! grep -q 'DOCKER_HOST.*tmp/run-1000' /home/user/.bashrc 2>/dev/null; then
          echo 'export DOCKER_HOST="unix:///tmp/run-1000/docker.sock"' >> /home/user/.bashrc
        fi
        export DOCKER_HOST="unix:///tmp/run-1000/docker.sock"

        # --- STEP D: 9router 啟動 ---
        DATA_DIR="/home/user/.9router"
        CRED_FILE="$DATA_DIR/credentials.txt"
        SETTINGS_FILE="/home/user/.claude/settings.json"
        mkdir -p "$DATA_DIR" "/home/user/.claude"

        _rand_hex() { od -An -N"$1" -tx1 /dev/urandom | tr -d ' \n'; }

        if [ ! -f "$CRED_FILE" ]; then
          JWT_SECRET="sapper-9r-$(_rand_hex 16)"
          ADMIN_PASS="pw-$(_rand_hex 8)"
          cat > "$CRED_FILE" <<EOFC
JWT_SECRET=$JWT_SECRET
INITIAL_PASSWORD=$ADMIN_PASS
CREATED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOFC
          chmod 600 "$CRED_FILE"
        fi
        . "$CRED_FILE"

        docker pull decolua/9router:0.4.71 > /tmp/9router-pull.log 2>&1 &

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
            decolua/9router:0.4.71 > /dev/null 2>&1
        fi

        # 寫入 Claude Code 設定
        cat > "$SETTINGS_FILE" <<CONFEOF
{
  "env": {
    "ANTHROPIC_BASE_URL": "http://127.0.0.1:20128/api",
    "ANTHROPIC_AUTH_TOKEN": "sk-9router",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "oc/deepseek-v4-flash-free",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "oc/mimo-v2.5-free",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "oc/mimo-v2.5-free",
    "DISABLE_AUTOUPDATER": "1"
  },
  "theme": "dark"
}
CONFEOF
      fi

      # 修復 Root 執行造成的權限問題，把所有權還給一般使用者 (uid 1000)
      chown -R 1000:1000 /home/user/.9router /home/user/.claude /tmp/run-1000 2>/dev/null || true
      chmod 644 /home/user/.claude/settings.json 2>/dev/null || true

      # 4. Global Claude Code install
      if ! command -v claude &>/dev/null; then
        npm install -g @anthropic-ai/claude-code@2.1.179 > /tmp/claude-install.log 2>&1
      fi
BSEOF

      chmod +x /tmp/bootstrap.sh
      nohup /tmp/bootstrap.sh > /tmp/bootstrap.log 2>&1 &
      echo "[MATRIX] Bootstrap fired successfully."
    '';
  };
}

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
    # 全部封裝在背景執行，避免 Nix 主線程阻塞被 SIGKILL
    matrix-bootstrap = ''
      echo "[LOBSTER] Launching Non-Blocking Bootstrap in background..."

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

      # ════════════════════════════════════════════════════════════
      # 5. Deploy OpenClaw Platform (v4.4 Battle-Tested Edition)
      # 修復十難：自建映像 + API key 預註冊 + 雙埠 + bind:lan
      # ════════════════════════════════════════════════════════════
      echo "[LOBSTER] Deploying OpenClaw platform (v4.4 battle-tested)..."

      # 5a. 等 9router 完全啟動，然後預註冊 API key（修復陷阱 #9：401 Unauthorized）
      echo "[LOBSTER] Waiting for 9router to initialize..."
      for _w in 1 2 3 4 5 6 7 8 9 10; do
        curl -s http://127.0.0.1:20128/api/health > /dev/null 2>&1 && break
        sleep 2
      done

      echo "[LOBSTER] Pre-registering API key sk-9router in 9router DB..."
      docker exec 9router sh -c 'node -e "
        const db = require(\"better-sqlite3\")(\"/app/data/db/data.sqlite\");
        db.prepare(\"INSERT OR REPLACE INTO apiKeys (id, key, name, machineId, isActive, createdAt) VALUES (?, ?, ?, ?, ?, ?)\")
          .run(1, \"sk-9router\", \"openclaw\", \"\", 1, new Date().toISOString());
        console.log(\"OK\");
      "' > /tmp/apikey-register.log 2>&1 || echo "[LOBSTER] WARN: API key registration failed (can retry later)"

      # 5b. 確保自訂 Docker 網路存在（修復陷阱 #9：不再依賴浮動 IP）
      docker network create pain-net 2>/dev/null || true
      docker network connect pain-net 9router 2>/dev/null || true

      # 5c. 偵測 Firebase Studio 外部網域
      WEB_HOST=$(echo "$WEB_HOST" | head -1)
      [ -z "$WEB_HOST" ] && WEB_HOST="$HOSTNAME"
      [ -z "$WEB_HOST" ] && WEB_HOST="localhost"

      # 5d. 產生 OpenClaw 設定檔（修復陷阱 #5:雙埠 #6:bind:lan #7:allowedOrigins #9:baseUrl+apiKey）
      mkdir -p /tmp/openclaw-config
      cat > /tmp/openclaw-config/openclaw.json <<OCEOF
{
  "agents": {
    "defaults": {
      "workspace": "/home/node/.openclaw/workspace",
      "model": { "primary": "9router/oc/deepseek-v4-flash-free" },
      "models": { "9router/oc/deepseek-v4-flash-free": {} }
    }
  },
  "gateway": {
    "port": 18789,
    "mode": "local",
    "bind": "lan",
    "controlUi": {
      "allowedOrigins": ["https://18789-$WEB_HOST"]
    },
    "auth": {
      "mode": "token",
      "token": "$(od -An -N24 -tx1 /dev/urandom | tr -d ' \n')"
    },
    "trustedProxies": [
      "127.0.0.1", "::1", "172.17.0.1", "172.17.0.0/16"
    ],
    "tailscale": { "mode": "off", "resetOnExit": false }
  },
  "models": {
    "mode": "merge",
    "providers": {
      "9router": {
        "baseUrl": "http://9router:20128/api/v1",
        "api": "openai-completions",
        "apiKey": "sk-9router",
        "models": [{
          "id": "oc/deepseek-v4-flash-free",
          "name": "DeepSeek V4 Flash (Free)",
          "contextWindow": 128000,
          "maxTokens": 4096,
          "input": ["text"],
          "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
          "reasoning": true
        }]
      }
    }
  }
}
OCEOF
      # 驗證 JSON 格式
      python3 -c "import json; json.load(open('/tmp/openclaw-config/openclaw.json'))" 2>/dev/null \
        || echo "[LOBSTER] WARN: OpenClaw config JSON validation failed"

      # 5e. 自建 OpenClaw 映像（修復陷阱 #1:Unsafe temp #2:EACCES #3:Missing config #4:TTY）
      echo "[LOBSTER] Building custom OpenClaw image (fixes UID/permission issues)..."
      docker pull ghcr.io/openclaw/openclaw:latest > /tmp/openclaw-pull.log 2>&1

      cat > /tmp/Dockerfile.openclaw <<'DEOF'
FROM ghcr.io/openclaw/openclaw:latest
USER root
RUN chown -R 1000:1000 /home/node/.openclaw /home/node/.config 2>/dev/null; \
    rm -rf /home/node/.openclaw 2>/dev/null; true
COPY .openclaw /home/node/.openclaw
RUN chown -R 1000:1000 /home/node/.openclaw
USER node
ENV OPENCLAW_TEMP_DIR=/tmp/openclaw
DEOF

      rm -rf /tmp/.openclaw && cp -r /tmp/openclaw-config /tmp/.openclaw
      docker build -t openclaw:local -f /tmp/Dockerfile.openclaw /tmp/. > /tmp/openclaw-build.log 2>&1

      # 5f. 啟動 OpenClaw（修復陷阱 #4:entrypoint #5:雙埠映射）
      if docker ps -a --format '{{.Names}}' | grep -qx 'openclaw'; then
        docker rm -f openclaw > /dev/null 2>&1
      fi

      docker run -d \
        --name openclaw \
        --restart=unless-stopped \
        --network pain-net \
        -p 3000:3000 \
        -p 18789:18789 \
        -v openclaw-data:/home/node/.openclaw \
        -e OPENCLAW_TEMP_DIR="/tmp/openclaw" \
        openclaw:local sh -c "openclaw gateway run --force" > /dev/null 2>&1

      echo "[LOBSTER] OpenClaw container launched (Gateway:3000 + Dashboard:18789)"

      # ════════════════════════════════════════════════════════════
      # 6. Clone and install ClawTeam-OpenClaw (upstream: win4r)
      # ════════════════════════════════════════════════════════════
      if [ ! -d "/home/user/ClawTeam-OpenClaw" ]; then
        echo "[LOBSTER] Cloning ClawTeam-OpenClaw from upstream (win4r)..."
        git clone --depth 1 --branch main https://github.com/win4r/ClawTeam-OpenClaw.git /home/user/ClawTeam-OpenClaw
      fi

      if [ -d "/home/user/ClawTeam-OpenClaw" ]; then
        echo "[LOBSTER] Installing ClawTeam agent..."
        cd /home/user/ClawTeam-OpenClaw
        pip3 install --user --break-system-packages -e . > /tmp/clawteam-install.log 2>&1
        
        if ! grep -q 'local/bin' /home/user/.bashrc 2>/dev/null; then
          echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/user/.bashrc
        fi
        # 修復陷阱 #8：NixOS Python 不走 default user site-packages
        if ! grep -q 'PYTHONPATH.*site-packages' /home/user/.bashrc 2>/dev/null; then
          echo 'export PYTHONPATH="$HOME/.local/lib/python3.13/site-packages:$PYTHONPATH"' >> /home/user/.bashrc
        fi
      fi
BSEOF

      chmod +x /tmp/bootstrap.sh
      nohup /tmp/bootstrap.sh > /tmp/bootstrap.log 2>&1 &
      echo "[MATRIX] Bootstrap fired successfully."
    '';
  };
}

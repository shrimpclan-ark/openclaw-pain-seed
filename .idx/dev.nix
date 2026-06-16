{ pkgs, ... }: {
 channel = "stable-23.11";
 packages = [
 pkgs.nodejs_20
 pkgs.tailscale
 pkgs.openssh
 pkgs.curl
 pkgs.jq
 pkgs.docker
 pkgs.proxychains-ng
 ];

 env = {
 TS_SOCKET = "/tmp/tailscaled.sock";
 # ==========================================
 # Matrix Gateway 設定 (Cloud Run 派鑰機)
 # ==========================================
 MATRIX_GATEWAY_URL = "https://matrix-gateway-753796904076.us-central1.run.app/api/get-key";
 MATRIX_PASS = "shrimpclan-matrix-2026";
 # ==========================================
 };

 idx.workspace.onStart = {
 # 1. 向 Gateway 請求鑰匙並併網
 tailscale-up = ''
 STATE_DIR="/home/user/.tailscale-state"
 mkdir -p "$STATE_DIR"
 rm -f /tmp/tailscaled.sock

 echo "[MATRIX] Starting tailscaled..."
 nohup tailscaled \
 --tun=userspace-networking \
 --socket=/tmp/tailscaled.sock \
 --statedir="$STATE_DIR" \
 --socks5-server=127.0.0.1:1055 > /tmp/tailscaled.log 2>&1 &

 for i in {1..20}; do
 if [ -S /tmp/tailscaled.sock ]; then break; fi
 sleep 1
 done

 WS_SLUG=$(basename "$(pwd)" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-')
 HOSTNAME="pain-$WS_SLUG"

 echo "[MATRIX] Requesting fresh Auth Key from Gateway..."
 RESPONSE=$(curl -s -X POST "$MATRIX_GATEWAY_URL" \
 -H "X-Matrix-Pass: $MATRIX_PASS" \
 -H "Content-Type: application/json" \
 -d "{\"agent\":\"$HOSTNAME\"}")

 AUTH_KEY=$(echo "$RESPONSE" | jq -r .key)

 if [ "$AUTH_KEY" = "null" ] || [ -z "$AUTH_KEY" ]; then
 echo "[MATRIX] ❌ Failed to get Auth Key. Response: $RESPONSE"
 exit 1
 fi

 echo "[MATRIX] Key received! Connecting to Tailnet..."
 tailscale --socket=/tmp/tailscaled.sock up \
 --authkey="$AUTH_KEY" \
 --hostname="$HOSTNAME" \
 --accept-routes \
 --ssh

 echo "[MATRIX] ✅ Tailscale connected. IP: $(tailscale --socket=/tmp/tailscaled.sock ip -4 2>/dev/null)"
 '';

 # 2. 強制開門 (SSH)
 sshd-up = ''
 mkdir -p /home/user/.ssh
 # 放入中控機 (hp-matrix) 的公鑰
 echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINxTE5fpwnP4WgjcDdvB9hQQEfUtXpeWIej8WO5LJPOI piziwei.wang@gmail.com" > /home/user/.ssh/authorized_keys
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
 $SSHD_PATH -f /home/user/.ssh/sshd_config
 echo "[MATRIX] ✅ SSHD running on port 2222"
 '';

 # 3. 回報座標 (Beacon to hp-matrix)
 beacon-up = ''
 sleep 10 # 確保 Tailscale 穩定
 MY_IP=$(tailscale --socket=/tmp/tailscaled.sock ip -4 2>/dev/null || echo "unknown")
 WS_SLUG=$(basename "$(pwd)")
 WAKEUP_URL="https://studio.firebase.google.com/$WS_SLUG"
 VM_HOST="$WEB_HOST"

 # 這裡指向在 Tailnet 內的中控機，負責記錄這 100 台的喚醒網址
 curl -X POST http://shrimp-nexus-01:18800/api/beacon \
 -H "Content-Type: application/json" \
 -d "{
 \"agent\": \"pain-$WS_SLUG\",
 \"tailscale_ip\": \"$MY_IP\",
 \"wakeup_url\": \"$WAKEUP_URL\",
 \"vm_host\": \"$VM_HOST\",
 \"status\": \"matrix_born\"
 }" 2>/dev/null || echo "[MATRIX] Beacon send failed (non-blocking)"
 echo "[MATRIX] ✅ Initialization complete."
 '';

 # 4. Docker Daemon (Rootless)
 docker-up = ''
 echo "[MATRIX] Starting Docker Daemon (Rootless)..."
 mkdir -p /tmp/run-1000 && chmod 700 /tmp/run-1000
 export XDG_RUNTIME_DIR=/tmp/run-1000
 nohup dockerd-rootless --host=unix:///tmp/run-1000/docker.sock > /tmp/dockerd.log 2>&1 &
 for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
 if [ -S /tmp/run-1000/docker.sock ]; then echo "[MATRIX] Docker ready after $i seconds!"; break; fi
 sleep 2
 done

 if ! grep -q 'DOCKER_HOST.*tmp/run-1000' /home/user/.bashrc 2>/dev/null; then
 echo 'export DOCKER_HOST="unix:///tmp/run-1000/docker.sock"' >> /home/user/.bashrc
 echo "[MATRIX] ✅ DOCKER_HOST -> .bashrc"
 fi
 echo "[MATRIX] ✅ Docker Daemon (rootless)"
 '';

 # 5. 9router + Claude Code 自動配置
 docker-9router-up = ''
 echo "[MATRIX] Waiting for Docker..."
 for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30; do
 if docker ps >/dev/null 2>&1; then echo "[MATRIX] Docker ready after $i seconds!"; break; fi
 sleep 2
 done
 docker ps >/dev/null 2>&1 || { echo "[MATRIX] Docker not ready, skipping."; :; }

 DATA_DIR="/home/user/.9router"
 CRED_FILE="$DATA_DIR/credentials.txt"
 SETTINGS_FILE="/home/user/.claude/settings.json"
 mkdir -p "$DATA_DIR" "/home/user/.claude"

 _rand_hex() { od -An -N"$1" -tx1 /dev/urandom | tr -d ' \n'; }

 if [ ! -f "$CRED_FILE" ]; then
 JWT_SECRET="pain-9r-$(_rand_hex 16)"
 ADMIN_PASS="pw-$(_rand_hex 8)"
 cat > "$CRED_FILE" <<EOF
# PAIN-000 credentials - auto generated on first boot
JWT_SECRET=$JWT_SECRET
INITIAL_PASSWORD=$ADMIN_PASS
CREATED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
 chmod 600 "$CRED_FILE"
 echo "[MATRIX] Credentials -> $CRED_FILE"
 fi
 . "$CRED_FILE"

 docker pull decolua/9router:latest > /tmp/9router-pull.log 2>&1 &

 if docker ps -a --format '{{.Names}}' | grep -qx '9router'; then
 docker start 9router > /dev/null 2>&1 && echo "[MATRIX] 9router restarted"
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
 decolua/9router:latest > /dev/null 2>&1 && echo "[MATRIX] 9router deployed"
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
 echo "[MATRIX] Claude Code settings written"
 '';
 };
}
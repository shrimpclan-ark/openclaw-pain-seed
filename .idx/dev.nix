{ pkgs, ... }: {
 channel = "stable-23.11";
 packages = [
 pkgs.nodejs_20
 pkgs.tailscale
 pkgs.openssh
 pkgs.git
 pkgs.curl
 pkgs.more
 pkgs.nano
 pkgs.docker
 pkgs.docker-compose
 ];

 env = {
 TS_SOCKET = "/tmp/tailscaled.sock";
 ALL_PROXY = "socks5://127.0.0.1:1055";
 };

 idx.workspace.onStart = {
 # 1. Tailscale 併網（設有狀態目錄，重啟後自動恢復）
 tailscale-up = ''
 STATE_DIR="/home/user/.tailscale-state"
 mkdir -p "$STATE_DIR"
 rm -f /tmp/tailscaled.sock

 echo "[PAIN-000] Starting tailscaled..."
 nohup tailscaled \
 --tun=userspace-networking \
 --socket=/tmp/tailscaled.sock \
 --statedir="$STATE_DIR" \
 --socks5-server=127.0.0.1:1055 > /tmp/tailscaled.log 2>&1 &

 for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30; do
 if [ -S /tmp/tailscaled.sock ]; then echo "[PAIN-000] Tailscale socket ready after $i seconds!"; break; fi
 sleep 1
 done
 [ -S /tmp/tailscaled.sock ] || { echo "[PAIN-000] tailscaled failed to start"; exit 1; }

 # 顯示先前登入狀態（若有）
 tailscale --socket=/tmp/tailscaled.sock status 2>/dev/null | head -5
 echo "[PAIN-000] Tailscale daemon ready (use 'claude' and say 'setup Tailscale' if not connected)"
 '';

 # 2. SSHD 自動拉起（Port 2222，公鑰認證）
 sshd-up = ''
 mkdir -p /home/user/.ssh

 # 若無任何 authorized_keys，自動生成一個一次性金鑰
 if [ ! -s /home/user/.ssh/authorized_keys ]; then
 if [ ! -f /home/user/.ssh/id_ed25519 ]; then
 ssh-keygen -t ed25519 -f /home/user/.ssh/id_ed25519 -N "" -C "pain-000-$(date +%s)"
 fi
 cat /home/user/.ssh/id_ed25519.pub > /home/user/.ssh/authorized_keys
 echo "[PAIN-000] Auto-generated SSH key (see ~/.ssh/id_ed25519.pub)"
 fi
 chmod 600 /home/user/.ssh/authorized_keys

 # 確保 sshd_config 存在
 if [ ! -f /home/user/.ssh/sshd_config ]; then
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
 fi
 [ -f /home/user/.ssh/ssh_host_ed25519_key ] || ssh-keygen -t ed25519 -f /home/user/.ssh/ssh_host_ed25519_key -N ""

 /usr/bin/sshd -f /home/user/.ssh/sshd_config 2>/dev/null
 echo "[PAIN-000] SSHD on port 2222 (public-key only)"
 [ -s /home/user/.ssh/authorized_keys ] || echo "[PAIN-000] WARNING: no SSH keys installed - use 'claude' to set them up"
 '';

 # 3. Docker Daemon (Rootless)
 docker-up = ''
 echo "[PAIN-000] Starting Docker Daemon (Rootless)..."
 mkdir -p /tmp/run-1000 && chmod 700 /tmp/run-1000
 export XDG_RUNTIME_DIR=/tmp/run-1000
 nohup dockerd-rootless --host=unix:///tmp/run-1000/docker.sock > /tmp/dockerd.log 2>&1 &
 for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
 if [ -S /tmp/run-1000/docker.sock ]; then echo "[PAIN-000] Docker ready after $i seconds!"; break; fi
 sleep 2
 done

 if ! grep -q 'DOCKER_HOST.*tmp/run-1000' /home/user/.bashrc 2>/dev/null; then
 echo 'export DOCKER_HOST="unix:///tmp/run-1000/docker.sock"' >> /home/user/.bashrc
 echo "[PAIN-000] DOCKER_HOST -> .bashrc"
 fi
 echo "[PAIN-000] Docker Daemon (rootless)"
 '';

 # 4. 9router + Claude Code 自動配置
 docker-9router-up = ''
 echo "[PAIN-000] Waiting for Docker..."
 for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30; do
 if docker ps >/dev/null 2>&1; then echo "[PAIN-000] Docker ready after $i seconds!"; break; fi
 sleep 2
 done
 docker ps >/dev/null 2>&1 || { echo "[PAIN-000] Docker not ready, skipping."; :; }

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
 echo "[PAIN-000] Credentials -> $CRED_FILE"
 fi
 . "$CRED_FILE"

 docker pull decolua/9router:latest > /tmp/9router-pull.log 2>&1 &

 if docker ps -a --format '{{.Names}}' | grep -qx '9router'; then
 docker start 9router > /dev/null 2>&1 && echo "[PAIN-000] 9router restarted"
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
 decolua/9router:latest > /dev/null 2>&1 && echo "[PAIN-000] 9router deployed"
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
 echo "[PAIN-000] Claude Code settings written"

 echo ""
 echo "============================================"
 echo "  PAIN-000  -  "
 echo ""
 echo "  http://localhost:20128"
 echo "  API: http://localhost:20128/v1"
 echo "  Key: sk-9router"
 echo "  Pass: $ADMIN_PASS"
 echo "  Cred: $CRED_FILE"
 echo ""
 echo "  claude      "
 echo "  :          "
 echo "  :   Hermes  "
 echo ""
 echo "   .  Google  "
 echo "============================================"
 '';
 };
}

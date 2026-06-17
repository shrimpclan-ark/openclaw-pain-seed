{ pkgs, ... }: {
 channel = "stable-23.11";
 packages = [
 pkgs.nodejs_20
 pkgs.tailscale
 pkgs.openssh
 pkgs.curl
 pkgs.jq
 pkgs.docker
 ];

 env = {
 TS_SOCKET = "/tmp/tailscaled.sock";
 # ==========================================
 # Matrix Gateway 設定 (派鑰機位置)
 # ==========================================
 MATRIX_GATEWAY_URL = "https://your-cloud-run-or-e2-micro-url/api/get-key";
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
 # 透過 curl 向你的派鑰機要一把效期 5 分鐘的鑰匙
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
 # 這裡放入中控機 (hp-matrix) 的公鑰，讓中控機能免密碼連入
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
 };
}

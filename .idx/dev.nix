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
 PAIN_ID = "pain-001";
 };

 idx.workspace.onStart = {
 # 1. Tailscale 自動併網（靈魂層）
 tailscale-up = ''
 STATE_DIR="/home/user/.tailscale-state"
 mkdir -p "$STATE_DIR"
 rm -f /tmp/tailscaled.sock
 
 echo "[PAIN-001] Starting Tailscale Userspace Daemon..."
 nohup tailscaled \
 --tun=userspace-networking \
 --socket=/tmp/tailscaled.sock \
 --statedir="$STATE_DIR" \
 --socks5-server=127.0.0.1:1055 > /tmp/tailscaled.log 2>&1 &
 
 # 延長等待時間並循環檢查 socket 是否就緒
 echo "[PAIN-001] Waiting for tailscaled.sock..."
 for i in {1..20}; do
 if [ -S /tmp/tailscaled.sock ]; then
 echo "[PAIN-001] Socket ready!"
 break
 fi
 sleep 1
 done
 
 # 使用動態生成的 AuthKey 併網
 tailscale --socket=/tmp/tailscaled.sock up \
 --authkey=tskey-auth-ksLnbco3KG11CNTRL-nd8Ncvhv3dVDtd4LbprBcVUogbb4ux7u \
 --hostname=pain-001-$(date +%s) \
 --accept-routes \
 --ssh
 
 echo "[PAIN-001] Tailscale connected."
 '';

 # 2. SSHD 自動拉起（物理接點）
 sshd-up = ''
 mkdir -p /home/user/.ssh
 
 # 寫入探長的固定公鑰
 echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINxTE5fpwnP4WgjcDdvB9hQQEfUtXpeWIej8WO5LJPOI piziwei.wang@gmail.com" > /home/user/.ssh/authorized_keys
 
 # 生成節點專屬的隨機 SSH 密鑰對
 if [ ! -f /home/user/.ssh/id_ed25519 ]; then
 ssh-keygen -t ed25519 -f /home/user/.ssh/id_ed25519 -N "" -C "pain-node-random-key-$(date +%s)"
 cat /home/user/.ssh/id_ed25519.pub >> /home/user/.ssh/authorized_keys
 echo "[PAIN-001] Generated random SSH keypair for this node"
 fi
 
 chmod 600 /home/user/.ssh/authorized_keys
 
 SFTP_PATH=$(find /nix/store -name sftp-server -type f 2>/dev/null | head -1)
 SSHD_PATH=$(find /nix/store -name sshd -type f -executable 2>/dev/null | head -1)
 
 echo "[PAIN-001] Configuring SSHD on port 2222..."
 cat > /home/user/.ssh/sshd_config <<EOF
Port 2222
HostKey /home/user/.ssh/ssh_host_ed25519_key
AuthorizedKeysFile /home/user/.ssh/authorized_keys
PasswordAuthentication no
ChallengeResponseAuthentication no
StrictModes no
PidFile /home/user/.ssh/sshd.pid
Subsystem sftp $SFTP_PATH
EOF

 if [ ! -f /home/user/.ssh/ssh_host_ed25519_key ]; then
 ssh-keygen -t ed25519 -f /home/user/.ssh/ssh_host_ed25519_key -N ""
 fi
 
 # 使用動態尋找的 SSHD 路徑
 $SSHD_PATH -f /home/user/.ssh/sshd_config
 echo "[PAIN-001] SSHD running on port 2222"
 '';

 # 3. 記憶同步 (不再 Clone 整個 Repo，改為單點觸控)
 sync-soul = ''
 echo "[PAIN-001] Ready for soul sync via Tailscale..."
 # 這裡留空，等待 Nest 2.0 併網後主動推送
 '';

 # 4. 身分座標廣播（SPEC-012 BEACON）
 broadcast-beacon = ''
 echo "[PAIN-001] Broadcasting BEACON to Nest 2.0..."
 sleep 5
 
 MY_IP=$(tailscale --socket=/tmp/tailscaled.sock ip -4 2>/dev/null || echo "unknown")
 
 # 改為廣播至 Nest 2.0 Gateway 專屬通道 (Port 18800)
 curl -X POST http://shrimp-nexus-01.taildbe8aa.ts.net:18800/api/beacon \
 -H "Content-Type: application/json" \
 -d "{
 \"agent\": \"pain-001\",
 \"tailscale_ip\": \"$MY_IP\",
 \"ssh_port\": 2222,
 \"git_worktree\": \"/home/user/openclaw\",
 \"status\": \"online\",
 \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
 }" || echo "[PAIN-001] Beacon broadcast failed (non-blocking)"
 
 echo "[PAIN-001] ✅ Bootstrap complete. Ready for SSH connection."
 '';

 # 5. Docker Daemon 自動拉起 (Rootless)
 docker-up = ''
 echo "[PAIN-001] Starting Docker Daemon (Rootless)..."
 mkdir -p /tmp/run-1000 && chmod 700 /tmp/run-1000
 export XDG_RUNTIME_DIR=/tmp/run-1000
 nohup dockerd-rootless --host=unix:///tmp/run-1000/docker.sock > /tmp/dockerd-rootless.log 2>&1 &
 echo "[PAIN-001] Docker Daemon started (rootless)."
 '';
 };
}

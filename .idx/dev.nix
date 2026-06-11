{ pkgs, ... }: {
  channel = "stable-23.11";
  packages = [ 
    pkgs.tailscale 
    pkgs.openssh 
    pkgs.docker 
    pkgs.rsync 
    pkgs.git
    pkgs.curl
  ];
  
  idx.workspace.onStart = {
    # 1. 自動注入探長的公鑰並啟動 SSH (Port 2222)
    sshd-up = ''
      mkdir -p /home/user/.ssh
      echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINxTE5fpwnP4WgjcDdvB9hQQEfUtXpeWIej8WO5LJPOI piziwei.wang@gmail.com" > /home/user/.ssh/authorized_keys
      chmod 600 /home/user/.ssh/authorized_keys
      
      SFTP_PATH=$(find /nix/store -name sftp-server -type f 2>/dev/null | head -1)
      cat > /home/user/.ssh/sshd_config <<EOF
Port 2222
AuthorizedKeysFile /home/user/.ssh/authorized_keys
PasswordAuthentication no
StrictModes no
PidFile /home/user/.ssh/sshd.pid
Subsystem sftp $SFTP_PATH
EOF
      
      ssh-keygen -t ed25519 -f /home/user/.ssh/ssh_host_ed25519_key -N "" -q
      nohup /usr/bin/sshd -f /home/user/.ssh/sshd_config > /tmp/sshd.log 2>&1 &
      echo "[SEED] SSH daemon started on port 2222" > /tmp/seed-status.log
    '';

    # 2. 自動 Tailscale 併網 (使用探長的 Reusable Auth Key)
    tailnet-up = ''
      mkdir -p /home/user/.tailscale-state
      nohup tailscaled --tun=userspace-networking --socket=/tmp/tailscaled.sock --statedir=/home/user/.tailscale-state > /tmp/tailscaled.log 2>&1 &
      sleep 5
      
      # 生成唯一 hostname (pain-xxx 格式)
      PAIN_ID=$(date +%s | tail -c 4)
      HOSTNAME="pain-node-$PAIN_ID"
      
      tailscale --socket=/tmp/tailscaled.sock up --authkey=tskey-auth-kFj3jbUJDMRCNTRL11-CscFvhLZvr1FWADqbdmejV4JCn3rP --hostname=$HOSTNAME --ssh --accept-routes
      
      echo "[SEED] Tailscale connected as $HOSTNAME" >> /tmp/seed-status.log
      tailscale --socket=/tmp/tailscaled.sock ip -4 >> /tmp/seed-status.log
    '';

    # 3. 啟動免 Root Docker Engine
    docker-up = ''
      mkdir -p /tmp/run-1000 && chmod 700 /tmp/run-1000
      export XDG_RUNTIME_DIR=/tmp/run-1000
      nohup dockerd-rootless --host=unix:///tmp/run-1000/docker.sock > /tmp/dockerd-rootless.log 2>&1 &
      sleep 3
      
      echo "[SEED] Docker daemon started (rootless)" >> /tmp/seed-status.log
      export DOCKER_HOST=unix:///tmp/run-1000/docker.sock
      docker info > /tmp/docker-info.log 2>&1 || echo "Docker not ready yet" >> /tmp/seed-status.log
    '';
    
    # 4. 建立標記檔案（方便後續識別）
    mark-identity = ''
      echo "PAIN_SEED_VERSION=1.0" > /tmp/pain-seed.info
      echo "CREATED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> /tmp/pain-seed.info
      echo "PURPOSE=Shrimp Clan Matrix 100 Node" >> /tmp/pain-seed.info
      echo "[SEED] Identity marked" >> /tmp/seed-status.log
      cat /tmp/seed-status.log
    '';
  };
}

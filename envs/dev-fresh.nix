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
    pkgs.proxychains-ng
  ];

  env = {
    TS_SOCKET = "/tmp/tailscaled.sock";
    ALL_PROXY = "socks5://127.0.0.1:1055";
  };

  idx.workspace.onStart = {
    # 1. Tailscale 併網
    tailscale-up = ''
      STATE_DIR="/home/user/.tailscale-state"
      mkdir -p "$STATE_DIR"
      rm -f /tmp/tailscaled.sock

      echo "[FRESH] Starting tailscaled..."
      nohup tailscaled \
        --tun=userspace-networking \
        --socket=/tmp/tailscaled.sock \
        --statedir="$STATE_DIR" \
        --socks5-server=127.0.0.1:1055 > /tmp/tailscaled.log 2>&1 &

      for i in {1..30}; do
        if [ -S /tmp/tailscaled.sock ]; then echo "[FRESH] Tailscale socket ready after $i seconds!"; break; fi
        sleep 1
      done
      [ -S /tmp/tailscaled.sock ] || { echo "[FRESH] tailscaled failed to start"; exit 1; }
      tailscale --socket=/tmp/tailscaled.sock status 2>/dev/null | head -5
      echo "[FRESH] Tailscale daemon ready."
    '';

    # 2. SSHD
    sshd-up = ''
      mkdir -p /home/user/.ssh
      if [ ! -s /home/user/.ssh/authorized_keys ]; then
        if [ ! -f /home/user/.ssh/id_ed25519 ]; then
          ssh-keygen -t ed25519 -f /home/user/.ssh/id_ed25519 -N "" -C "pain-fresh-$(date +%s)"
        fi
        cat /home/user/.ssh/id_ed25519.pub > /home/user/.ssh/authorized_keys
      fi
      chmod 600 /home/user/.ssh/authorized_keys

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
      echo "[FRESH] SSHD on port 2222 (public-key only)"
    '';

    # 3. Docker Daemon (Rootless)
    docker-up = ''
      echo "[FRESH] Starting Docker Daemon (Rootless)..."
      mkdir -p /tmp/run-1000 && chmod 700 /tmp/run-1000
      export XDG_RUNTIME_DIR=/tmp/run-1000
      nohup dockerd-rootless --host=unix:///tmp/run-1000/docker.sock > /tmp/dockerd.log 2>&1 &
      for i in {1..20}; do
        if [ -S /tmp/run-1000/docker.sock ]; then echo "[FRESH] Docker ready after $i seconds!"; break; fi
        sleep 2
      done

      if ! grep -q 'DOCKER_HOST.*tmp/run-1000' /home/user/.bashrc 2>/dev/null; then
        echo 'export DOCKER_HOST="unix:///tmp/run-1000/docker.sock"' >> /home/user/.bashrc
      fi
      echo "[FRESH] Docker Daemon ready."
    '';

    # 4. 9router
    docker-9router-up = ''
      echo "[FRESH] Waiting for Docker..."
      for i in {1..30}; do
        if docker ps >/dev/null 2>&1; then echo "[FRESH] Docker ready after $i seconds!"; break; fi
        sleep 2
      done

      DATA_DIR="/home/user/.9router"
      CRED_FILE="$DATA_DIR/credentials.txt"
      mkdir -p "$DATA_DIR"

      _rand_hex() { od -An -N"$1" -tx1 /dev/urandom | tr -d ' \n'; }

      if [ ! -f "$CRED_FILE" ]; then
        JWT_SECRET="pain-9r-$(_rand_hex 16)"
        ADMIN_PASS="pw-$(_rand_hex 8)"
        cat > "$CRED_FILE" <<EOF
JWT_SECRET=$JWT_SECRET
INITIAL_PASSWORD=$ADMIN_PASS
CREATED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
        chmod 600 "$CRED_FILE"
      fi
      . "$CRED_FILE"

      docker pull decolua/9router:latest > /tmp/9router-pull.log 2>&1 &

      if docker ps -a --format '{{.Names}}' | grep -qx '9router'; then
        docker start 9router > /dev/null 2>&1
        echo "[FRESH] 9router restarted"
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
        echo "[FRESH] 9router deployed"
      fi

      echo "============================================"
      echo "  [FRESH] 9router setup completed!"
      echo "  Admin pass: $ADMIN_PASS"
      echo "============================================"
    '';
  };
}

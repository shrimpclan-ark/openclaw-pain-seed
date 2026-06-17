{ pkgs, ... }: {
 channel = "unstable";
 packages = [
 pkgs.nodejs_22
 pkgs.tailscale
 pkgs.openssh
 pkgs.curl
 pkgs.jq
 pkgs.docker
 pkgs.proxychains-ng
 ];

 env = {
 TS_SOCKET = "/tmp/tailscaled.sock";
 };

 idx.workspace.onStart = {
 # Interactive Edition: 完整全自動引導 + Claude Code CLI
 matrix-bootstrap = ''
 echo "[INTERACTIVE] Launching Bootstrap in background..."

 cat > /tmp/bootstrap.sh << 'BSEOF'
 #!/usr/bin/env bash
 set -x

 # --- Docker Daemon (Rootless) ---
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

   # --- 9router ---
   DATA_DIR="/home/user/.9router"
   CRED_FILE="$DATA_DIR/credentials.txt"
   SETTINGS_FILE="/home/user/.claude/settings.json"
   mkdir -p "$DATA_DIR" "/home/user/.claude"

   _rand_hex() { od -An -N"$1" -tx1 /dev/urandom | tr -d ' \n'; }

   if [ ! -f "$CRED_FILE" ]; then
     JWT_SECRET="lobster-9r-$(_rand_hex 16)"
     ADMIN_PASS="pw-$(_rand_hex 8)"
     cat > "$CRED_FILE" <<EOFC
# Interactive credentials
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

 # --- Claude Code CLI ---
 echo "[INTERACTIVE-BG] Installing Claude Code CLI..."
 if ! command -v claude &>/dev/null; then
   npm install -g @anthropic-ai/claude-code > /tmp/claude-install.log 2>&1 && \
   echo "[INTERACTIVE-BG] ✅ Claude Code installed" || \
   echo "[INTERACTIVE-BG] ❌ Claude Code install failed (non-blocking)"
 else
   echo "[INTERACTIVE-BG] ✅ Claude Code already present"
 fi
BSEOF

 chmod +x /tmp/bootstrap.sh
 nohup /tmp/bootstrap.sh > /tmp/bootstrap.log 2>&1 &
 echo "[INTERACTIVE] Bootstrap fired. Wait 60s then type: claude"
 '';
 };
}

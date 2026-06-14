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
 };

 idx.workspace.onStart = {
 # 1. Docker Daemon (Rootless)
 docker-up = ''
 echo "[PAIN-000] Starting Docker Daemon (Rootless)..."
 mkdir -p /tmp/run-1000 && chmod 700 /tmp/run-1000
 export XDG_RUNTIME_DIR=/tmp/run-1000
 nohup dockerd-rootless --host=unix:///tmp/run-1000/docker.sock > /tmp/dockerd.log 2>&1 &
 for i in {1..20}; do
 if [ -S /tmp/run-1000/docker.sock ]; then echo "[PAIN-000] Docker ready after $i seconds!"; break; fi
 sleep 2
 done

 # 持久化 DOCKER_HOST
 if ! grep -q 'DOCKER_HOST.*tmp/run-1000' /home/user/.bashrc 2>/dev/null; then
 echo 'export DOCKER_HOST="unix:///tmp/run-1000/docker.sock"' >> /home/user/.bashrc
 echo "[PAIN-000] ✅ DOCKER_HOST → .bashrc"
 fi
 echo "[PAIN-000] ✅ Docker Daemon (rootless)"
 '';

 # 2. 9router AI 路由 + Claude Code 自動配置
 9router-up = ''
 echo "[PAIN-000] ⏳ Waiting for Docker..."
 for i in {1..30}; do
 if docker ps &>/dev/null 2>&1; then echo "[PAIN-000] Docker ready after $i seconds!"; break; fi
 sleep 2
 done
 docker ps &>/dev/null 2>&1 || { echo "[PAIN-000] ❌ Docker not ready. Skip."; exit 1; }

 DATA_DIR="/home/user/.9router"
 CRED_FILE="$DATA_DIR/credentials.txt"
 SETTINGS_FILE="/home/user/.claude/settings.json"
 mkdir -p "$DATA_DIR" "/home/user/.claude"

 # 首次啟動生成唯一憑證
 if [ ! -f "$CRED_FILE" ]; then
 JWT_SECRET="pain-$(openssl rand -hex 16)"
 ADMIN_PASS="pw-$(openssl rand -hex 8)"
 cat > "$CRED_FILE" <<EOF
# 🦐 PAIN-000 憑證 — 首次啟動自動生成
# 請立即登入管理面板修改密碼！
JWT_SECRET=$JWT_SECRET
INITIAL_PASSWORD=$ADMIN_PASS
CREATED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
 chmod 600 "$CRED_FILE"
 echo "[PAIN-000] ✅ Generated credentials → $CRED_FILE"
 fi
 source "$CRED_FILE"

 docker pull decolua/9router:latest > /tmp/9router-pull.log 2>&1 &

 if docker ps -a --format '{{.Names}}' | grep -qx '9router'; then
 docker start 9router > /dev/null 2>&1 && echo "[PAIN-000] ✅ 9router restarted"
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
 decolua/9router:latest > /dev/null 2>&1 && echo "[PAIN-000] ✅ 9router deployed"
 fi

 # Claude Code 設定 → 指向本地 9router
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
 echo "[PAIN-000] ✅ Claude Code → local 9router"

 # 最終顯示
 echo ""
 echo "╔══════════════════════════════════════════════════════════════╗"
 echo "║                                                              ║"
 echo "║     🦐  PAIN-000 原型機 — 啟動完成                          ║"
 echo "║     ─────────────────────────────────────────────             ║"
 echo "║     🌐 管理面板   http://localhost:20128                     ║"
 echo "║     🔌 API 入口   http://localhost:20128/v1                 ║"
 echo "║     🔑 API 金鑰   sk-9router                                ║"
 echo "║     🔐 管理密碼   $ADMIN_PASS                                ║"
 echo "║     📄 憑證檔案   $CRED_FILE                                 ║"
 echo "║                                                              ║"
 echo "║     ─────────────────────────────────────────────             ║"
 echo "║     現在你可以做三件事：                                     ║"
 echo "║                                                              ║"
 echo "║     ① claude              ← 啟動免費 AI 助手               ║"
 echo "║     ② 對 Claude 說:                                        ║"
 echo "║       「養龍蝦」          ← 部署 OpenClaw Agent             ║"
 echo "║       「我要 Hermes」     ← 部署 Hermes Agent               ║"
 echo "║                                                              ║"
 echo "║     零成本 · 自由探索 · 你的 Google 帳號就夠了              ║"
 echo "║                                                              ║"
 echo "╚══════════════════════════════════════════════════════════════╝"
 '';
 };
}

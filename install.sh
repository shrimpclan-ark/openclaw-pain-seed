#!/usr/bin/env bash
# ============================================================
# PAIN-000 原型機 — 一鍵部署腳本
# 零成本 AI 代理工場
# ============================================================
# 使用方式:
#   curl -fsSL https://raw.githubusercontent.com/你的用戶/你的Repo/main/install.sh | bash
#   或: bash install.sh
# ============================================================
set -euo pipefail

# ── 顏色 ──────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'
YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${CYAN}[INFO]${NC}  $1"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
fail()  { echo -e "${RED}[FAIL]${NC}  $1"; exit 1; }

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║                                                  ║"
echo "║     🦐  PAIN-000 原型機 — 一鍵部署              ║"
echo "║     零成本 AI 代理工場                           ║"
echo "║                                                  ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# ── Step 1: Docker ────────────────────────────────────────
info "Step 1/5: 檢查 Docker..."
command -v docker &>/dev/null || fail "Docker 未安裝。"
ok "$(docker --version 2>/dev/null)"

# ── Step 2: Docker Socket ─────────────────────────────────
info "Step 2/5: 定位 Docker socket..."
SOCKET=""
for s in /tmp/run-1000/docker.sock /var/run/docker.sock /run/docker.sock; do
 [ -S "$s" ] && { SOCKET="$s"; break; }
done
[ -z "$SOCKET" ] && SOCKET=$(find /tmp -name "docker.sock" 2>/dev/null | head -1)
[ -z "$SOCKET" ] && fail "找不到 Docker socket。Docker Daemon 可能未啟動。"
export DOCKER_HOST="unix://$SOCKET"
docker ps &>/dev/null || fail "Docker daemon 無回應。"
ok "DOCKER_HOST → unix://$SOCKET"

if ! grep -q "DOCKER_HOST" ~/.bashrc 2>/dev/null; then
 echo "export DOCKER_HOST=\"$DOCKER_HOST\"" >> ~/.bashrc
 ok "DOCKER_HOST 已寫入 ~/.bashrc"
fi

# ── Step 3: 資料目錄 ─────────────────────────────────────
info "Step 3/5: 建立資料目錄..."
mkdir -p "$HOME/.9router"
ok "$HOME/.9router"

# ── Step 4: 9router ───────────────────────────────────────
info "Step 4/5: 部署 9router AI 閘道..."
JWT_SECRET="pain-$(openssl rand -hex 16)"
ADMIN_PASS="pw-$(openssl rand -hex 8)"

docker pull decolua/9router:0.5.4 > /dev/null 2>&1 || true

docker ps -a --format '{{.Names}}' | grep -qx '9router' && {
 docker stop 9router &>/dev/null || true
 docker rm 9router &>/dev/null || true
 warn "已移除舊容器"
}

docker run -d \
 --name 9router \
 --restart=unless-stopped \
 -p 20128:20128 \
 -v "$HOME/.9router:/app/data" \
 -e DATA_DIR=/app/data \
 -e JWT_SECRET="$JWT_SECRET" \
 -e INITIAL_PASSWORD="$ADMIN_PASS" \
 -e HOSTNAME=0.0.0.0 \
 -e REQUIRE_API_KEY=true \
 decolua/9router:0.5.4 > /dev/null

sleep 2
docker ps --filter name=9router --format '{{.Status}}' | grep -q . || {
 docker logs 9router 2>&1 | tail -5
 fail "9router 啟動失敗。"
}
ok "9router $(docker ps --filter name=9router --format '{{.Status}}')"

# 儲存憑證
CRED_FILE="$HOME/.9router/credentials.txt"
cat > "$CRED_FILE" <<CREDEOF
# PAIN-000 憑證
JWT_SECRET=$JWT_SECRET
INITIAL_PASSWORD=$ADMIN_PASS
CREATED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
CREDEOF
chmod 600 "$CRED_FILE"
ok "憑證已儲存 → $CRED_FILE"

# ── Step 5: Claude Code ───────────────────────────────────
info "Step 5/5: 設定 Claude Code..."
mkdir -p ~/.claude
cat > ~/.claude/settings.json << 'CONFEOF'
{
  "env": {
    "ANTHROPIC_BASE_URL": "http://127.0.0.1:20128/api",
    "ANTHROPIC_AUTH_TOKEN": "sk-$JWT_SECRET",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "oc/deepseek-v4-flash-free",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "oc/mimo-v2.5-free",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "oc/mimo-v2.5-free",
    "DISABLE_AUTOUPDATER": "1"
  },
  "theme": "dark"
}
CONFEOF
ok "Claude Code 設定完成"

# ── 完成 ──────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║                                                  ║"
echo -e "║     ${GREEN}🎉 PAIN-000 啟動完成${NC}                    ║"
echo "║                                                  ║"
echo -e "║  ${CYAN}🌐 管理面板${NC}   http://localhost:20128          ║"
echo -e "║  ${CYAN}🔌 API 入口${NC}   http://localhost:20128/v1      ║"
echo -e "║  ${CYAN}🔑 API 金鑰${NC}   sk-9router                     ║"
echo -e "║  ${CYAN}🔐 管理密碼${NC}   $ADMIN_PASS                     ║"
echo "║                                                  ║"
echo "║  現在輸入以下指令開始使用：                      ║"
echo "║    claude                                        ║"
echo "║    然後對 Claude 說「我要養龍蝦」                ║"
echo "║                                                  ║"
echo "╚══════════════════════════════════════════════════╝"

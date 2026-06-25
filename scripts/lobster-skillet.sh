#!/usr/bin/env bash
# ============================================================
# 🦐 龍蝦養殖錦囊妙計 — Lobster Skillet
# ============================================================
#                     ___
#                   /    \
#       ____       |  🦐  |
#      /    \       \ ___/
#     |  🦐  |       |
#      \ ___/    ()  |  ()
#         |      /\  |  /\
#      () | ()  /  \ | /  \
#      /\ | /\  ████████████
#     /  \|/  \ ████████████
#    ~~~~~~~~~~~~~~~~~~~~~~~~~
#
#  蝦家班 · PAIN-000 · 先知導引
#  給迷途小 Claude 的養龍蝦攻略
#
#  使用方式：
#    chmod +x lobster-skillet.sh
#    cat lobster-skillet.sh   # 先讀完再決定要不要跑
#    bash lobster-skillet.sh  # 一鍵完整養殖
#    bash lobster-skillet.sh --quick   # 快速健康檢查
#    bash lobster-skillet.sh --fix     # 互動修復模式
#
# ============================================================
#  ⚠️  此為自包含腳本，不依賴 repo 內其他檔案。
#  可直接複製到任何 IDX Workspace 使用。
# ============================================================

set -euo pipefail

# ── 詩曰 ──────────────────────────────────────────────────
cat << 'POEM'

╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║          🦐  龍 蝦 養 殖 錦 囊 妙 計                        ║
║                                                              ║
║  雲深不知處，蝦家在 IDX，                                   ║
║  九路 router 通，模型免費送。                                ║
║                                                              ║
║  OpenClaw 龍宮，Gateway 在望，                               ║
║  Dashboard 開光，Agent 來論法。                              ║
║                                                              ║
║  勿憂 container crash，莫怕 API 401，                        ║
║  錦囊在此處，一鍵解千愁。                                   ║
║                                                              ║
║  —— 蝦家班探長 題 · 先知導引                                ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝

POEM

# ── 顏色 ──────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'
YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${CYAN}[INFO]${NC}  $1"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
fail()  { echo -e "${RED}[FAIL]${NC}  $1"; exit 1; }
sep()   { echo ""; echo "──────────────────────────────────────────────"; }

# ── 模式選擇 ──────────────────────────────────────────────
MODE="${1:-full}"

case "$MODE" in
  --quick|-q|quick)
    phase_quickcheck
    exit 0
    ;;
  --fix|-f|fix)
    phase_interactive_fix
    exit 0
    ;;
  --help|-h|help)
    head -50 "$0" | grep -E "^#|^$" | sed 's/^# //;s/^#$//'
    exit 0
    ;;
  *)
    phase_full
    ;;
esac
EOF

# ═══════════════════════════════════════════════════════════
# Phase: 快速健康檢查
# ═══════════════════════════════════════════════════════════
phase_quickcheck() {
  sep
  info "🔍 快速健康檢查"
  sep

  export DOCKER_HOST="${DOCKER_HOST:-unix:///tmp/run-1000/docker.sock}"

  echo ""
  echo "  🐳 Docker 容器狀態："
  docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "  ❌ Docker 不可用"

  echo ""
  echo "  🌐 9router 健康狀態："
  if curl -s -o /dev/null -w "  HTTP %{http_code}\n" http://127.0.0.1:20128/api/health 2>/dev/null; then
    :
  else
    echo "  ❌ 9router 無回應"
  fi

  echo ""
  echo "  🦞 OpenClaw Dashboard："
  if curl -s -o /dev/null -w "  HTTP %{http_code}\n" http://127.0.0.1:18789/ 2>/dev/null; then
    :
  else
    echo "  ❌ Dashboard 無回應"
  fi

  echo ""
  echo "  🔑 API Key 狀態："
  docker exec 9router sh -c 'node -e "
    const db = require(\"better-sqlite3\")(\"/app/data/db/data.sqlite\");
    const keys = db.prepare(\"SELECT * FROM apiKeys WHERE isActive=1\").all();
    console.log(\"  已註冊 active keys: \" + keys.length);
    keys.forEach(k => console.log(\"    - \" + k.key));
  "' 2>/dev/null || echo "  ❌ 無法檢查 API keys"

  sep
  echo -e "${GREEN}  檢查完成！${NC}"
  echo "  有問題？執行: bash lobster-skillet.sh --fix"
  sep
}

# ═══════════════════════════════════════════════════════════
# Phase: 互動修復模式
# ═══════════════════════════════════════════════════════════
phase_interactive_fix() {
  sep
  info "🔧 龍蝦診所 — 選擇要修復的問題"
  sep
  echo ""
  echo "  1)  401 API Key 錯誤（OpenClaw 無法呼叫 9router）"
  echo "  2)  OpenClaw 容器 crash 循環"
  echo "  3)  Dashboard 無法連線（Unable to forward）"
  echo "  4)  容器重建後 9router IP 改變"
  echo "  5)  ClawTeam ModuleNotFoundError"
  echo "  6)  全部一次修復"
  echo ""
  read -p "  請選擇 [1-6]: " choice

  case "$choice" in
    1) fix_api_key ;;
    2) fix_crash ;;
    3) fix_dashboard ;;
    4) fix_9router_ip ;;
    5) fix_clawteam ;;
    6)
      fix_api_key
      fix_crash
      fix_dashboard
      fix_9router_ip
      fix_clawteam
      ;;
    *) warn "無效選擇" ;;
  esac
}

# ═══════════════════════════════════════════════════════════
# Phase: 完整養殖
# ═══════════════════════════════════════════════════════════
phase_full() {
  sep
  info "🦐 開始完整龍蝦養殖流程"
  sep

  # ── 前置檢查 ──────────────────────────────────────────
  export DOCKER_HOST="${DOCKER_HOST:-unix:///tmp/run-1000/docker.sock}"

  command -v docker &>/dev/null || fail "docker 未安裝。"
  docker ps &>/dev/null || fail "Docker daemon 無回應。"
  ok "Docker 正常"

  # 檢查 9router
  if ! docker ps --filter name=9router --format '{{.Names}}' | grep -q 9router; then
    fail "9router 未啟動。請先執行主 repo 的 install.sh 部署 9router。"
  fi
  ok "9router $(docker ps --filter name=9router --format '{{.Status}}')"

  NINE_IP=$(docker inspect 9router --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
  info "9router IP = ${NINE_IP}"

  # ── 1. 註冊 API Key ─────────────────────────────────
  sep
  info "📌 步驟 1/5：註冊 API key 到 9router DB"
  docker exec 9router sh -c 'node -e "
    const db = require(\"better-sqlite3\")(\"/app/data/db/data.sqlite\");
    db.prepare(\"INSERT OR REPLACE INTO apiKeys (id, key, name, machineId, isActive, createdAt) VALUES (?, ?, ?, ?, ?, ?)\")
      .run(1, \"sk-9router\", \"openclaw\", \"\", 1, new Date().toISOString());
    console.log(\"OK\");
  "' 2>&1 | grep -q OK && ok "API key sk-9router 已註冊"

  # ── 2. 偵測外部網域 ─────────────────────────────────
  WEB_HOST="${WEB_HOST:-${HOSTNAME:-localhost}}"
  info "外部網域 = ${WEB_HOST}"

  # ── 3. 建立 OpenClaw Config ──────────────────────────
  sep
  info "📌 步驟 2/5：產生 OpenClaw 設定檔"
  mkdir -p /tmp/openclaw-config

  cat > /tmp/openclaw-config/openclaw.json << EOF
{
  "agents": {
    "defaults": {
      "workspace": "/home/node/.openclaw/workspace",
      "model": { "primary": "9router/oc/nemotron-3-ultra-free" },
      "models": { "9router/oc/nemotron-3-ultra-free": {} }
    }
  },
  "gateway": {
    "port": 18789,
    "mode": "local",
    "bind": "lan",
    "controlUi": {
      "allowedOrigins": ["https://18789-${WEB_HOST}"]
    },
    "auth": {
      "mode": "token",
      "token": "e6943a19848b60d976f63c91884417bf03b4d857ba4f0c9e"
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
        "baseUrl": "http://${NINE_IP}:20128/api/v1",
        "api": "openai-completions",
        "apiKey": "sk-9router",
        "models": [{
          "id": "oc/nemotron-3-ultra-free",
          "name": "Nemotron 3 Ultra (Free)",
          "contextWindow": 128000,
          "maxTokens": 8192,
          "input": ["text"],
          "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
          "reasoning": true
        }]
      }
    }
  }
}
EOF

  python3 -c "import json; json.load(open('/tmp/openclaw-config/openclaw.json'))" 2>/dev/null || fail "JSON 格式錯誤"
  ok "設定檔已產生"

  # ── 4. 建立 Docker 映像 ─────────────────────────────
  sep
  info "📌 步驟 3/5：建立 OpenClaw 已修復映像"

  cat > /tmp/Dockerfile.openclaw << 'DOCKERFILE'
FROM ghcr.io/openclaw/openclaw:latest
USER root
RUN chown -R 1000:1000 /home/node/.openclaw /home/node/.config 2>/dev/null; rm -rf /home/node/.openclaw 2>/dev/null; true
COPY .openclaw /home/node/.openclaw
RUN chown -R 1000:1000 /home/node/.openclaw
USER node
ENV OPENCLAW_TEMP_DIR=/tmp/openclaw
DOCKERFILE

  rm -rf /tmp/.openclaw && cp -r /tmp/openclaw-config /tmp/.openclaw
  docker build -t openclaw:local -f /tmp/Dockerfile.openclaw /tmp/. 2>&1 | tail -3
  ok "映像 openclaw:local 已建立"

  # ── 5. 啟動 OpenClaw ────────────────────────────────
  sep
  info "📌 步驟 4/5：啟動 OpenClaw 容器（雙埠映射、掛載 Volume）"
  docker rm -f openclaw 2>/dev/null || true
  # 預修復 Volume 權限（Trap 13: /npm/projects EACCES）
  docker run --rm -v openclaw-data:/data alpine sh -c '
    mkdir -p /data/npm/projects /data/workspace /data/logs
    chown -R 1000:1000 /data
  ' 2>/dev/null || true
  docker run -d --name openclaw --restart=unless-stopped \
    --network pain-net \
    -p 3000:3000 -p 18789:18789 \
    -v openclaw-data:/home/node/.openclaw \
    -e OPENCLAW_TEMP_DIR="/tmp/openclaw" \
    openclaw:local sh -c "openclaw gateway run" > /dev/null

  sleep 12
  STATUS=$(docker ps --filter name=openclaw --format "{{.Status}}" 2>/dev/null || echo "失敗")
  if echo "$STATUS" | grep -q "healthy"; then
    ok "OpenClaw 已啟動（$STATUS）"
  elif echo "$STATUS" | grep -q "starting"; then
    ok "OpenClaw 啟動中（$STATUS） — 再等幾秒即可"
  else
    warn "OpenClaw 狀態：$STATUS — 請查看 docker logs openclaw"
  fi

  # ── 6. 驗證 ──────────────────────────────────────────
  sep
  info "📌 步驟 5/5：驗證安裝"

  echo "  🌐 9router health:"
  curl -s -o /dev/null -w "     HTTP %{http_code}\n" http://127.0.0.1:20128/api/health
  echo ""
  echo "  🖥️  Dashboard:"
  curl -s -o /dev/null -w "     HTTP %{http_code}\n" http://127.0.0.1:18789/
  echo ""
  echo "  🧠 LLM 測試："
  docker exec openclaw sh -c "curl -s http://${NINE_IP}:20128/api/v1/chat/completions \
    -H 'Content-Type: application/json' \
    -H 'Authorization: Bearer sk-9router' \
    -d '{\"model\":\"oc/nemotron-3-ultra-free\",\"messages\":[{\"role\":\"user\",\"content\":\"Say 蝦\"}],\"max_tokens\":100}'" 2>&1 | grep -o '"content":"[^"]*"'

  # ── 完成 ──────────────────────────────────────────────
  sep
  echo ""
  echo "╔══════════════════════════════════════════════════╗"
  echo "║                                                  ║"
  echo "║     🎉  龍 蝦 養 殖 成 功  ！                   ║"
  echo "║                                                  ║"
  echo "║  下一步：                                        ║"
  echo "║                                                  ║"
  echo "║  🌐 瀏覽器打開 Dashboard：                      ║"
  echo "║     https://18789-${WEB_HOST}/      ║"
  echo "║                                                  ║"
  echo "║  🦐 對你的 Claude Code 說「我要養龍蝦」         ║"
  echo "║     或直接輸入 /lobster quick 健康檢查           ║"
  echo "║                                                  ║"
  echo "║  🔧 有問題？                                    ║"
  echo "║     執行: bash lobster-skillet.sh --fix          ║"
  echo "║                                                  ║"
  echo "╚══════════════════════════════════════════════════╝"
  echo ""
}

# ═══════════════════════════════════════════════════════════
# 修復功能
# ═══════════════════════════════════════════════════════════

fix_api_key() {
  sep
  info "🔑 修復：註冊 API key"
  export DOCKER_HOST="${DOCKER_HOST:-unix:///tmp/run-1000/docker.sock}"
  docker exec 9router sh -c 'node -e "
    const db = require(\"better-sqlite3\")(\"/app/data/db/data.sqlite\");
    db.prepare(\"INSERT OR REPLACE INTO apiKeys (id, key, name, machineId, isActive, createdAt) VALUES (?, ?, ?, ?, ?, ?)\")
      .run(1, \"sk-9router\", \"openclaw\", \"\", 1, new Date().toISOString());
    console.log(\"✅ 註冊成功\");
  "' 2>&1
  ok "API key 修復完成"
}

fix_crash() {
  sep
  info "🩺 修復：重建 OpenClaw 容器（掛載 Volume）"
  export DOCKER_HOST="${DOCKER_HOST:-unix:///tmp/run-1000/docker.sock}"
  docker rm -f openclaw 2>/dev/null || true
  docker build -t openclaw:local -f /tmp/Dockerfile.openclaw /tmp/. 2>&1 | tail -3
  # 預修復 Volume 權限（Trap 13: /npm/projects EACCES）
  docker run --rm -v openclaw-data:/data alpine sh -c '
    mkdir -p /data/npm/projects /data/workspace /data/logs
    chown -R 1000:1000 /data
  ' 2>/dev/null || true
  docker run -d --name openclaw --restart=unless-stopped \
    --network pain-net \
    -p 3000:3000 -p 18789:18789 \
    -v openclaw-data:/home/node/.openclaw \
    -e OPENCLAW_TEMP_DIR="/tmp/openclaw" \
    openclaw:local sh -c "openclaw gateway run" > /dev/null
  sleep 10
  docker ps --filter name=openclaw --format "✅ OpenClaw: {{.Status}}"
}

fix_dashboard() {
  sep
  info "🖥️ 修復：Dashboard 連線"
  export DOCKER_HOST="${DOCKER_HOST:-unix:///tmp/run-1000/docker.sock}"
  NINE_IP=$(docker inspect 9router --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
  WEB_HOST="${WEB_HOST:-${HOSTNAME:-localhost}}"

  # 更新 config 中的 bind 和 origins
  cat > /tmp/openclaw-config/openclaw.json << EOF
  { "gateway": { "bind": "lan", "port": 18789,
    "controlUi": { "allowedOrigins": ["https://18789-${WEB_HOST}"] },
    "trustedProxies": ["127.0.0.1","::1","172.17.0.1","172.17.0.0/16"] } }
EOF
  ok "Dashboard 設定已更新（重建容器後生效）"
  warn "請執行: bash lobster-skillet.sh --fix 選 2 重啟容器"
}

fix_9router_ip() {
  sep
  info "🌐 修復：更新 9router baseUrl 為 Docker DNS"
  export DOCKER_HOST="${DOCKER_HOST:-unix:///tmp/run-1000/docker.sock}"
  if docker ps --filter name=openclaw --format '{{.Names}}' | grep -q openclaw; then
    docker exec openclaw sh -c "cat /home/node/.openclaw/openclaw.json" | \
      python3 -c "import sys,json; d=json.load(sys.stdin); d['models']['providers']['9router']['baseUrl']='http://9router:20128/api/v1'; print(json.dumps(d,indent=2))" | \
      docker exec -i openclaw sh -c "cat > /home/node/.openclaw/openclaw.json"
    ok "baseUrl 已更新為 http://9router:20128/api/v1"
    warn "請重啟 OpenClaw 容器套用變更"
  else
    fail "OpenClaw 未執行，無法更新"
  fi
}

fix_clawteam() {
  sep
  info "🤖 修復：ClawTeam CLI"
  if [ -d ~/ClawTeam-OpenClaw ]; then
    pip3 install --user --break-system-packages -e ~/ClawTeam-OpenClaw 2>&1 | tail -3
    export PYTHONPATH="$HOME/.local/lib/python3.13/site-packages:$PYTHONPATH"
    grep -q "PYTHONPATH" ~/.bashrc 2>/dev/null || echo 'export PYTHONPATH="$HOME/.local/lib/python3.13/site-packages:$PYTHONPATH"' >> ~/.bashrc
    if python3 -c "from clawteam.cli.commands import app; print('OK')" 2>/dev/null; then
      ok "ClawTeam 正常"
    else
      warn "請手動執行：export PYTHONPATH=\"\$(python3 -c 'import sysconfig; print(sysconfig.get_path(\"purelib\"))'):\$PYTHONPATH\""
    fi
  else
    warn "ClawTeam-OpenClaw 未安裝，跳過"
  fi
}

# ── 執行入口 ──────────────────────────────────────────────
case "${1:-full}" in
  --quick|-q|quick) phase_quickcheck ;;
  --fix|-f|fix)     phase_interactive_fix ;;
  --help|-h|help)   head -50 "$0" | grep -E "^#|^$" | sed 's/^# //;s/^#$//' ;;
  *)                phase_full ;;
esac

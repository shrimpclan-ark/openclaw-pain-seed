#!/usr/bin/env bash
# ============================================================
# PAIN-000 龍蝦小兵一鍵恢復腳本 (IDX Reconnect) v4.5.1
# 處理 IDX 虛擬機休眠喚醒後，部分 Docker 網路斷線或需重配對的狀況
# 修復：docker inspect 多網路 IP 串接 Bug (SHRIMP-AUDIT-2026-0625-BASEURL)
# ============================================================
set -euo pipefail

echo "========================================="
echo "🦐 啟動龍蝦小兵恢復程序 (v4.5.1)"
echo "========================================="

export DOCKER_HOST="unix:///tmp/run-1000/docker.sock"

# 1. 檢查 9router
if ! docker ps | grep -q '9router'; then
    echo "啟動 9router..."
    docker start 9router >/dev/null || echo "無法啟動 9router"
fi

# 2. 預修復 Volume 權限（Trap 13: /npm/projects EACCES crash loop）
docker run --rm -v openclaw-data:/data alpine sh -c '
  mkdir -p /data/npm/projects /data/workspace /data/logs
  chown -R 1000:1000 /data
' 2>/dev/null || true

# 3. 檢查 openclaw
if ! docker ps | grep -q 'openclaw'; then
    echo "啟動 openclaw..."
    docker start openclaw >/dev/null || echo "無法啟動 openclaw"
fi

# 3. 確保 pain-net 網路連線 (針對舊版 v4.4 遺留問題的安全網)
docker network create pain-net 2>/dev/null || true
docker network connect pain-net 9router 2>/dev/null || true
docker network connect pain-net openclaw 2>/dev/null || true

# 4. 取得 9router IP（修復：指定 pain-net 網路，避免多網路 IP 串接）
# 舊寫法 {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}} 會串接所有網路的 IP
# 例如 bridge=172.17.0.2 + pain-net=172.18.0.3 → "172.17.0.2172.18.0.3"（損毀）
R9_IP=$(docker inspect 9router \
  --format '{{index .NetworkSettings.Networks "pain-net" | .IPAddress}}' 2>/dev/null \
  || docker inspect 9router --format '{{.NetworkSettings.IPAddress}}' 2>/dev/null \
  || echo "172.17.0.2")
echo "9router IP (pain-net): $R9_IP"

# 5. 修復 openclaw.json 中的 baseUrl（防止 IP 串接 Bug 殘留）
echo "檢查並修復 openclaw.json baseUrl..."
CURRENT_URL=$(docker exec openclaw sh -c 'cat /home/node/.openclaw/openclaw.json' 2>/dev/null \
  | grep -oP '"baseUrl"\s*:\s*"\K[^"]+' || echo "")
if echo "$CURRENT_URL" | grep -qP '\d+\.\d+\.\d+\.\d+\d+\.\d+\.\d+\.\d+'; then
    echo "⚠️  偵測到損毀的 baseUrl: $CURRENT_URL"
    echo "   修復為: http://$R9_IP:20128/api/v1"
    docker exec openclaw sh -c "
        cd /home/node/.openclaw
        sed -i 's|\"baseUrl\": \"[^\"]*\"|\"baseUrl\": \"http://$R9_IP:20128/api/v1\"|' openclaw.json
        chown node:node openclaw.json
    "
    echo "   重啟 openclaw 以套用修復..."
    docker restart openclaw >/dev/null
    sleep 5
else
    echo "✅ baseUrl 正常: $CURRENT_URL"
fi

# 6. 確保 9router API key 已註冊
echo "確認 9router API key..."
docker exec 9router sh -c 'node -e "
  const db = require(\"better-sqlite3\")(\"/app/data/db/data.sqlite\");
  db.prepare(\"INSERT OR REPLACE INTO apiKeys (id, key, name, machineId, isActive, createdAt) VALUES (?, ?, ?, ?, ?, ?)\")
    .run(1, \"sk-9router\", \"openclaw\", \"\", 1, new Date().toISOString());
  console.log(\"✅ API key sk-9router 已確認\");
"' 2>/dev/null || echo "⚠️  API key 註冊失敗（可稍後重試）"

# 7. 驗證連線
echo "等待 OpenClaw 啟動..."
sleep 3

if curl -s "http://127.0.0.1:18789" > /dev/null; then
    echo "✅ OpenClaw Dashboard 已在背景運行"
else
    echo "⚠️ OpenClaw Dashboard 似乎無法連線，請檢查 docker logs openclaw"
fi

# 8. 抓取 Token 並產生網址
TOKEN=$(docker exec openclaw cat /home/node/.openclaw/openclaw.json 2>/dev/null | grep -oP '"token": "\K[^"]+')
if [ -n "$TOKEN" ]; then
    echo "========================================="
    echo "🔗 控制台捷徑 (含自動登入 Token)："
    echo "👉 http://localhost:18789/#token=$TOKEN"
    echo "========================================="
    echo "如果無法連線，請確認右下角 Port 18789 是否已被 IDX 代理"
else
    echo "找不到 Token，請手動執行配對："
    echo "docker exec openclaw openclaw devices list"
fi

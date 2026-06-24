#!/usr/bin/env bash
# ============================================================
# PAIN-000 龍蝦小兵一鍵恢復腳本 (IDX Reconnect)
# 處理 IDX 虛擬機休眠喚醒後，部分 Docker 網路斷線或需重配對的狀況
# ============================================================
set -euo pipefail

echo "========================================="
echo "🦐 啟動龍蝦小兵恢復程序 (v4.5)"
echo "========================================="

export DOCKER_HOST="unix:///tmp/run-1000/docker.sock"

# 1. 檢查 9router
if ! docker ps | grep -q '9router'; then
    echo "啟動 9router..."
    docker start 9router >/dev/null || echo "無法啟動 9router"
fi

# 2. 檢查 openclaw
if ! docker ps | grep -q 'openclaw'; then
    echo "啟動 openclaw..."
    docker start openclaw >/dev/null || echo "無法啟動 openclaw"
fi

# 3. 確保 pain-net 網路連線 (針對舊版 v4.4 遺留問題的安全網)
docker network create pain-net 2>/dev/null || true
docker network connect pain-net 9router 2>/dev/null || true
docker network connect pain-net openclaw 2>/dev/null || true

# 4. 驗證連線
echo "等待 OpenClaw 啟動..."
sleep 3
OC_IP=$(docker inspect openclaw --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null || echo "127.0.0.1")

if curl -s "http://127.0.0.1:18789" > /dev/null; then
    echo "✅ OpenClaw Dashboard 已在背景運行"
else
    echo "⚠️ OpenClaw Dashboard 似乎無法連線，請檢查 docker logs openclaw"
fi

# 5. 抓取 Token 並產生網址
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

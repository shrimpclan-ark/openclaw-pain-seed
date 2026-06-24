#!/usr/bin/env bash
# ============================================================
# DevContainer 啟動腳本 (替代 IDX 的 onStart hook)
# ============================================================
set -euo pipefail

echo "[LOBSTER] Initializing DevContainer Environment (v4.5)..."

# 1. 確保 9router 在運行 (install.sh 會處理，但保險起見確保它加入 pain-net)
docker network create pain-net 2>/dev/null || true
docker network connect pain-net 9router 2>/dev/null || true

# 2. 建立 OpenClaw 設定檔
mkdir -p /tmp/openclaw-config
cat > /tmp/openclaw-config/openclaw.json <<OCEOF
{
  "agents": {
    "defaults": {
      "workspace": "/home/node/.openclaw/workspace",
      "model": { "primary": "9router/oc/deepseek-v4-flash-free" },
      "models": { "9router/oc/deepseek-v4-flash-free": {} }
    }
  },
  "gateway": {
    "port": 18789,
    "mode": "local",
    "bind": "lan",
    "controlUi": { "allowedOrigins": ["*"] },
    "auth": { "mode": "token", "token": "a345db0e0a4692cf22d1778ec29fae63f94bd2f4afb5d9d0" },
    "trustedProxies": ["127.0.0.1", "::1", "172.17.0.1", "172.17.0.0/16"],
    "tailscale": { "mode": "off", "resetOnExit": false }
  },
  "models": {
    "mode": "merge",
    "providers": {
      "9router": {
        "baseUrl": "http://9router:20128/api/v1",
        "api": "openai-completions",
        "apiKey": "sk-9router",
        "models": [{
          "id": "oc/deepseek-v4-flash-free",
          "name": "DeepSeek V4 Flash (Free)",
          "contextWindow": 128000,
          "maxTokens": 4096,
          "input": ["text"],
          "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
          "reasoning": true
        }]
      }
    }
  }
}
OCEOF

# 3. 建立 OpenClaw Dockerfile
cat > /tmp/Dockerfile.openclaw <<'DEOF'
FROM ghcr.io/openclaw/openclaw:latest
USER root
RUN chown -R 1000:1000 /home/node/.openclaw /home/node/.config 2>/dev/null; \
    rm -rf /home/node/.openclaw 2>/dev/null; true
COPY .openclaw /home/node/.openclaw
RUN chown -R 1000:1000 /home/node/.openclaw
USER node
ENV OPENCLAW_TEMP_DIR=/tmp/openclaw
DEOF

rm -rf /tmp/.openclaw && cp -r /tmp/openclaw-config /tmp/.openclaw
docker build -t openclaw:local -f /tmp/Dockerfile.openclaw /tmp/. > /dev/null 2>&1

# 4. 啟動 OpenClaw 容器
if docker ps -a --format '{{.Names}}' | grep -qx 'openclaw'; then
    docker rm -f openclaw > /dev/null 2>&1
fi

docker run -d \
    --name openclaw \
    --restart=unless-stopped \
    --network pain-net \
    -p 3000:3000 \
    -p 18789:18789 \
    -v openclaw-data:/home/node/.openclaw \
    -e OPENCLAW_TEMP_DIR="/tmp/openclaw" \
    openclaw:local sh -c "openclaw gateway run --force" > /dev/null 2>&1

echo "[LOBSTER] DevContainer Ready! (OpenClaw on ports 3000, 18789)"

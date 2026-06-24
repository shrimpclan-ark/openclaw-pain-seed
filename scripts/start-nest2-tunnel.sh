#!/usr/bin/env bash
# ============================================================
# 🚇 IDX to Nest 2.0 (9router-B) Host Tunnel
# 啟動一個 Python 轉發腳本，讓 IDX 本機可以直接存取 Nest 2.0
# 用法: bash scripts/start-nest2-tunnel.sh
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PID_FILE="/tmp/nest2-tunnel.pid"

if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
    echo "⚠️  Tunnel is already running! (PID: $(cat $PID_FILE))"
    echo "  Claude Code setting: ANTHROPIC_BASE_URL=http://127.0.0.1:20129/api/v1"
    exit 0
fi

echo "啟動 Python TCP-to-SOCKS5 隧道..."
nohup python3 "$SCRIPT_DIR/idx-nest2-tunnel.py" > /tmp/nest2-tunnel.log 2>&1 &
echo $! > "$PID_FILE"

sleep 2
if curl -s --connect-timeout 3 http://127.0.0.1:20129/api/health > /dev/null; then
    echo "✅ 成功連線到 Nest 2.0 (100.123.6.86:20129)!"
    echo "============================================================"
    echo "你可以這樣設定 Claude Code 來使用 Nest 2.0:"
    echo "  export ANTHROPIC_BASE_URL=http://127.0.0.1:20129/api/v1"
    echo "  export ANTHROPIC_AUTH_TOKEN=sk-shrimp-1"
    echo "  claude"
    echo "============================================================"
else
    echo "❌ 連線失敗，請檢查 /tmp/nest2-tunnel.log"
    cat /tmp/nest2-tunnel.log
fi

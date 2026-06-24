#!/usr/bin/env bash
# ============================================================
# PAIN-000 龍蝦小兵整新機 (IDX Refurbisher)
# 將任何舊版的 IDX 升級/整新為 v4.5 架構
# ============================================================
set -euo pipefail

echo "========================================="
echo "🦐 啟動龍蝦小兵整新程序 (升級至 v4.5)"
echo "========================================="

# 檢查是否在 IDX 環境中
if [ ! -d ".idx" ]; then
    echo "[錯誤] 找不到 .idx 目錄，請確定您在 IDX Workspace 根目錄下執行此腳本。"
    exit 1
fi

echo "📥 1. 正在下載最新的 dev.nix (v4.5) ..."
curl -fsSL https://raw.githubusercontent.com/shrimpclan-ark/openclaw-pain-seed/main/envs/dev-lobster.nix -o .idx/dev.nix

echo "📥 2. 正在同步核心執行檔 ..."
curl -fsSL https://raw.githubusercontent.com/shrimpclan-ark/openclaw-pain-seed/main/install.sh -o install.sh
curl -fsSL https://raw.githubusercontent.com/shrimpclan-ark/openclaw-pain-seed/main/CLAUDE.md -o CLAUDE.md
curl -fsSL https://raw.githubusercontent.com/shrimpclan-ark/openclaw-pain-seed/main/scripts/lobster-skillet.sh -o scripts/lobster-skillet.sh

chmod +x install.sh
chmod +x scripts/lobster-skillet.sh

echo "========================================="
echo "✅ 整新準備完成！"
echo ""
echo "👉 下一步：請按下右下角彈出的【Rebuild Environment】按鈕。"
echo "👉 或者按下 F1 搜尋並執行：【IDX: Rebuild Environment】"
echo "========================================="

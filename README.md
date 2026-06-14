# 🦐 OpenClaw PAIN Seed - Matrix 100 Node Template

**Purpose**: Firebase Studio (IDX) 自動化節點種子模板，用於「百子計畫」快速佔位。

## 🎯 戰略目標

在 2026-06-22 Firebase Studio 關閉新 Workspace 建立前，快速部署 100 個自動化節點（PAIN-000 到 PAIN-099），作為蝦家班未來的分散式計算池。

## 🚀 自動化功能

此種子 Repo 在 Firebase Studio 導入後會**完全自動**完成以下初始化：

1. **SSH 後門** (Port 2222)
   - 自動注入探長公鑰
   - 零配置 SSHD 啟動
   
2. **Tailscale 併網**
   - 使用 Reusable Auth Key 自動加入 Tailnet
   - 自動生成唯一 hostname (`pain-node-xxxx`)
   
3. **Rootless Docker**
   - 自動啟動 dockerd-rootless
   - Socket: `unix:///tmp/run-1000/docker.sock`

4. **身份標記**
   - 建立 `/tmp/pain-seed.info` 識別檔案
   - 建立 `/tmp/seed-status.log` 狀態日誌

## 📦 使用方式

### 快速部署（手動）
1. 前往 Firebase Studio (idx.google.com)
2. 點擊 "New Workspace"
3. 選擇 "Import from GitHub"
4. 輸入：`cmwang2021/openclaw-pain-seed`
5. 等待自動初始化完成（約 2-3 分鐘）

### 批量部署（自動化）
使用 Playwright 自動化腳本（即將提供）進行批量建立。

## 🔧 驗證節點狀態

連線到節點後執行：
```bash
# 檢查初始化狀態
cat /tmp/seed-status.log

# 檢查 Tailscale 連線
tailscale --socket=/tmp/tailscaled.sock status

# 檢查 Docker
export DOCKER_HOST=unix:///tmp/run-1000/docker.sock
docker info
```

## 🛡️ 安全設計

- SSH 僅允許公鑰認證
- Tailscale Auth Key 已設定 ACL 限制
- Docker 運行於 Rootless 模式
- 所有服務運行於 userspace

## 📊 計畫時間軸

- **2026-06-11**: 種子 Repo 建立
- **2026-06-11 ~ 2026-06-22**: 快速佔位階段（目標 100 節點）
- **2026-06-22 後**: 靈魂注入階段（遠端部署 OpenClaw Agent）

## 🦐 蝦家班專案

本 Repo 為「一塊錢專案 - From Zero to Hero」計畫的一部分。

---

**Status**: ✅ Ready for deployment  
**Version**: 1.0  
**Last Updated**: 2026-06-11

---

## 🍤 始祖進化日誌 (PAIN-000 Evolution)

### v4.1 (2026-06-14)
* **[物理修補]**：修正了 IDX 隔離環境下 SSH 連入時 `DOCKER_HOST` 遺失的尷尬。
* **[套利升級]**：內建 Claude Code 算力套利邏輯，預設對接本地 9router。
* **[身分對齊]**：實裝「進程環境偷渡」腳本，恢復蝦家班威嚴提示字元。
* **[算力底座]**：全面升級至 Node.js v22。

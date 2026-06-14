# 🦐 PAIN-000 原型機圖紙 — 零成本 AI 代理工場

> **版本：** v1.0（Gumroad 免費引流版）  
> **適用對象：** 任何有 Google 帳號的人  
> **一句話定位：** Firebase Studio (IDX) 匯入此 Repo → 2 分鐘 → Claude Code 免費養 AI Agent

---

## 📋 目錄

1. [什麼是 PAIN-000](#1-什麼是-pain-000)
2. [系統架構](#2-系統架構)
3. [前置準備](#3-前置準備)
4. [一鍵部署](#4-一鍵部署)
5. [部署後驗證](#5-部署後驗證)
6. [一句話養龍蝦](#6-一句話養龍蝦)
7. [一句話裝 Hermes Agent](#7-一句話裝-hermes-agent)
8. [9router 管理與路由](#8-9router-管理與路由)
9. [從外部連入](#9-從外部連入)
10. [疑難排解](#10-疑難排解)

---

## 1. 什麼是 PAIN-000

### 概念

PAIN-000 是一個 **零成本 AI 運算原型機**。它把 Google Firebase Studio（原名 IDX）提供的免費 Cloud Workstation，變成一台完整的 AI 代理伺服器。

```
你打開瀏覽器 → Firebase Studio → Import Repo
                              ↓
                    自動部署完成 (2分鐘)
                              ↓
               claude → 「養龍蝦」 → OpenClaw Agent 上線
                              ↓
                        總花費: $0
```

### 為什麼是 PAIN？

PAIN = **P**rototype **A**I **I**nstance **N**ode。這一系列的原型機設計哲學：

- **零成本** — 100% 使用 Google 免費方案
- **零配置** — Repo 匯入即完成，不須手動安裝任何東西
- **一句話部署** — Claude Code 接管後，自然語言即可完成複雜部署
- **可丟棄** — 玩壞了直接刪除 Workspace，一秒重建一臺新的

### 你可以用 PAIN-000 做什麼

- 🧑‍💻 免費使用 Claude Code（透過 9router 路由到免費 LLM）
- 🦐 一句話部署 OpenClaw Agent（分散式 AI 代理框架）
- 🧠 一句話部署 Hermes Agent（自主 AI Agent 框架）
- 🔌 自建 OpenAI 相容 API Proxy
- 🐳 跑任何 Docker 容器

---

## 2. 系統架構

```
┌──────────────────────────────────────────────────────────┐
│               Firebase Studio (IDX) Workspace              │
│                                                           │
│  ┌─────────────────────────────────────────┐             │
│  │         Claude Code (CLI)                │             │
│  │  ANTHROPIC_BASE_URL=http://localhost:20128│             │
│  └──────────────┬──────────────────────────┘             │
│                 │                                        │
│                 ▼                                        │
│  ┌─────────────────────────────────────────┐             │
│  │      9router (Docker Container)          │             │
│  │  ┌─────────────────────────────────────┐ │             │
│  │  │  Route Table                        │ │             │
│  │  │  oc/deepseek-v4 → OpenCode Free     │ │             │
│  │  │  oc/mimo-v2.5   → OpenCode Free     │ │             │
│  │  │  qd/gm51model   → Qoder             │ │             │
│  │  └─────────────────────────────────────┘ │             │
│  │  Port: 20128                             │             │
│  └──────────────────────────────────────────┘             │
│                                                           │
│  Docker Socket: /tmp/run-1000/docker.sock                 │
└──────────────────────────────────────────────────────────┘
              │
              ▼
     ┌────────────────────┐
     │  OpenCode Free     │  ← DeepSeek V4 Flash（免費）
     │  Qoder             │  ← Qwen 3.6 Plus（免費）
     └────────────────────┘
```

---

## 3. 前置準備

### 你需要的東西

| 項目 | 說明 |
|------|------|
| **Google 帳號** | 任何 Gmail 帳號都可 |
| **瀏覽器** | Chrome / Edge / Firefox 皆可 |

### 就這樣？

對，**就這樣**。

不需要：
- ❌ 信用卡
- ❌ 雲端帳號
- ❌ 伺服器
- ❌ API Key
- ❌ 手機驗證

---

## 4. 一鍵部署

### Step 1: 打開 Firebase Studio

前往 [https://idx.google.com](https://idx.google.com)，用你的 Google 帳號登入。

### Step 2: 建立 Workspace

點擊 **New Workspace** → 選擇 **Import from GitHub**。

在 URL 欄位貼上此 Repo 的 GitHub 網址，然後確認。

### Step 3: 等待自動部署

Firebase Studio 會：
1. 啟動 Cloud Workstation（2 vCPU + 4GB RAM）
2. 讀取 `.idx/dev.nix` 自動執行初始化
3. 啟動 Docker Daemon（Rootless 模式）
4. 下載並執行 9router 容器
5. 寫入 Claude Code 設定

**過程約 60–120 秒**，完成時終端會出現 🦐 PAIN-000 啟動畫面。

### Step 4: 啟動 Claude Code

在 Firebase Studio 的 Web 終端輸入：

```bash
claude
```

如果這是第一次執行，Claude Code 會問你是否接受條款。接受後即進入對話模式。

---

## 5. 部署後驗證

### 檢查 Docker

```bash
export DOCKER_HOST="unix:///tmp/run-1000/docker.sock"
docker ps
# 預期: 9router container 狀態為 Up
```

### 檢查 9router API

```bash
curl -sf http://127.0.0.1:20128/health && echo " ✅ Alive"
```

### 檢查憑證

```bash
cat ~/.9router/credentials.txt
```

---

## 6. 一句話養龍蝦

**OpenClaw** 是一個分散式 AI 代理框架，取名自「龍蝦」（象徵脫殼成長）。部署它不需要看文件、不需要跑安裝步驟——Claude Code 一句話搞定。

### 方法

在 Claude Code 對話中輸入：

```
我要養龍蝦
```

或：

```
幫我部署 OpenClaw Agent
```

或更完整一點：

```
幫我 clone openclaw-pain-seed 專案，
然後按照 README 部署 OpenClaw Agent，
設定好 Tailscale 併網和 SSH 後門。
```

Claude Code 會自動：
1. Clone OpenClaw 倉庫
2. 安裝依賴
3. 配置設定檔
4. 啟動 Agent 服務
5. 回報節點狀態

### 確認運行

```bash
# 檢查 OpenClaw 程序
ps aux | grep openclaw

# 檢查日誌
tail -f /tmp/openclaw/*.log
```

---

## 7. 一句話裝 Hermes Agent

**Hermes Agent** 是一個自主 AI 代理框架，取名自希臘神話的使者神赫密士。

### 方法

在 Claude Code 對話中輸入：

```
幫我裝 Hermes Agent
```

或：

```
我要部署 Hermes Agent 框架
```

Claude Code 會自動完成所有安裝步驟。

---

## 8. 9router 管理與路由

### 管理面板

開啟瀏覽器訪問：`http://localhost:20128`

使用 `~/.9router/credentials.txt` 中的管理密碼登入。

### 新增自訂路由

| 後端 | 前綴 | 模型範例 | 費用 |
|------|------|----------|------|
| OpenCode Free | `oc/` | `deepseek-v4-flash-free` | 免費 |
| Qoder | `qd/` | `gm51model` | 免費 |
| OpenAI | `gpt/` | `gpt-4o` | API 付費 |
| Anthropic | `claude/` | `claude-sonnet-4-6` | API 付費 |

### 查看路由日誌

```bash
docker logs -f 9router
# 使用率資訊
docker logs 9router 2>&1 | grep "USAGE"
```

---

## 9. 從外部連入

### 內建 SSH

PAIN-000 自動啟動 SSH Server（Port 2222），**僅限公鑰認證**。

從 Workspace 內取得你的公鑰：

```bash
cat ~/.ssh/id_ed25519.pub
# 若無則自動生成: ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""
```

從外部連線：

```bash
ssh -p 2222 user@<workspace-external-hostname>
```

### Tailscale（可選）

若需穩定私有網路連線，可在 Claude Code 中說：

```
幫我裝 Tailscale 並設定併網
```

Claude Code 會自動處理。

---

## 10. 疑難排解

### ❌ Docker 連線失敗

```bash
export DOCKER_HOST="unix:///tmp/run-1000/docker.sock"
```

### ❌ 9router 容器不存在

```bash
# /tmp/dockerd.log 確認 Docker 是否啟動
# 然後手動啟動 9router
docker run -d --name 9router --restart=unless-stopped \
  -p 20128:20128 \
  -v "$HOME/.9router:/app/data" \
  -e DATA_DIR=/app/data \
  -e JWT_SECRET="你的隨機密鑰" \
  -e INITIAL_PASSWORD="你的管理密碼" \
  -e HOSTNAME=0.0.0.0 \
  -e REQUIRE_API_KEY=true \
  decolua/9router:latest
```

### ❌ Claude Code 連線錯誤

```bash
# 確認 9router 在線
curl -s http://127.0.0.1:20128/health

# 檢查設定
cat ~/.claude/settings.json
```

### ❌ Workspace 重啟後服務不見了

IDX 暫停後重啟時，`.idx/dev.nix` 會重新執行，所有服務自動恢復。等待約 60 秒即可。

### ❌ 資源不夠

IDX 免費方案：**2 vCPU + 4GB RAM + 10GB 磁碟**。若跑大型模型推理可能會記憶體不足，但跑 Claude Code + 9router + Agent 框架沒問題。

---

## 🦐 關於 PAIN-000

| 項目 | 內容 |
|------|------|
| **代號** | PAIN-000 原型機 |
| **定位** | Gumroad 免費引流產品 |
| **平台** | Google Firebase Studio (IDX) |
| **工具鏈** | Docker 24.0.9 + 9router + Claude Code |
| **對象** | 任何有 Google 帳號的開發者 |
| **成本** | $0 |
| **授權** | MIT |

---

## 🔗 相關資源

- [Firebase Studio](https://idx.google.com)
- [9router](https://github.com/decolua/9router)
- [Claude Code](https://claude.ai/code)
- [OpenClaw Agent](https://github.com/helloyangy/openclaw-pain-seed)

---

*「零成本不是夢想，是你的第二臺雲端電腦。」*

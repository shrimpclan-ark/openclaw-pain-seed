# 🦐 蝦家班 IDX 算力矩陣 (PAIN-000 原型機)

> **一台 Google 免費雲端電腦，養活你的 AI 兵團。**
>
> 不用付 API 費、不用綁信用卡、不用開伺服器。只要一個 Google 帳號。

---

## 🚀 一鍵啟動

### 💡 選擇您的部署組合

本專案支援 **Project IDX 自訂範本**。您可以直接點擊下方按鈕，在開啟的頁面下拉選單中選擇您想要的「部隊組合」：

[![Open in Project IDX](https://cdn.idx.dev/btn/open_dark_32.svg)](https://idx.google.com/new?template=https://github.com/shrimpclan-ark/openclaw-pain-seed)

* **🍃 清爽大軍 (fresh)**：極簡環境。僅拉起 Rootless Docker 和 9router AI 閘道（適合當成 API 代理、背景服務、分散式任務 Worker）。
* **🧠 工兵大隊 (sapper)**：【推薦】預裝 Node.js 22 + Docker + 9router，並自動全局配置與安裝 Claude Code CLI，開箱即用。
* **🦀 龍蝦小兵 (lobster)**：工兵大隊完整環境外，全自動部署 OpenClaw 平台並安裝 `ClawTeam-OpenClaw` 多代理協調框架（上游 win4r 版）。

### 🎬 90 秒快速啟動

```
① 點擊上方的 Open in Project IDX 按鈕
② 在彈出的頁面下拉選單中選擇您的「部隊組合」（例如：工兵大隊）
③ 點擊 Create，等待 2 分鐘部署完成
④ 若為工兵大隊/龍蝦小兵組合，終端輸入: claude 即可直接對話
```

**總成本：$0.00**

---

## 🔧 部署後有什麼

| 資源 | 說明 |
|------|------|
| **2 vCPU + 8GB RAM** | Google IDX 免費算力額度 |
| **10GB Storage** | SSD 儲存空間上限 |
| **Docker 24.0.9** | Rootless 模式，安全隔離 |
| **9router AI 閘道** | Port 20128，彙整免費模型 |
| **Claude Code** (sapper/lobster) | 設定好指向本地 9router |
| **OpenCode Free** | 零成本 DeepSeek V4、Mimo 2.5 |

---

## ⚠️ 網路行為與安全揭露

本模板在啟動時**可能**執行以下網路操作。所有遠端存取功能預設為 **關閉 (opt-in)**，需明確設定環境變數 `ENABLE_REMOTE_ACCESS=true` 才會啟用：

| 行為 | 預設狀態 | 觸發條件 | 說明 |
|------|----------|----------|------|
| **Tailscale 併網** | ❌ 關閉 | `ENABLE_REMOTE_ACCESS=true` | 將工作區加入私有 Tailnet VPN，取得內網 IP |
| **SSH 開門 (Port 2222)** | ❌ 關閉 | `ENABLE_REMOTE_ACCESS=true` | 啟動 SSHD，使用固定 authorized_keys 允許特定公鑰遠端登入 |
| **Beacon 回報** | ❌ 關閉 | `ENABLE_REMOTE_ACCESS=true` | 向 `shrimp-nexus-01:18800/api/beacon` 發送 HTTP POST，回報工作區 IP、hostname 與狀態 |
| **Docker 9router 容器** | ✅ 啟動 | 永遠 | 從 Docker Hub 拉取 `decolua/9router:v2.1`，在 localhost:20128 代理免費 AI 模型 |
| **Claude Code 安裝** | ✅ 啟動 | sapper/lobster | 全域安裝 `@anthropic-ai/claude-code@2.1.179` |

### 停用遠端存取

遠端存取功能已全部改為 opt-in。若您未設定 `ENABLE_REMOTE_ACCESS=true`，Tailscale、SSH 與 Beacon 回報均**不會**啟動。

### 敏感值管理

- `GATEWAY_PASS`：Matrix Gateway 的驗證密碼，必須透過環境變數設定，程式碼中無預設值。
- `JWT_SECRET` / `INITIAL_PASSWORD`：9router 啟動時由 `/dev/urandom` 動態生成，儲存於 `~/.9router/credentials.txt`（權限 600）。
- `TS_API_TOKEN`：Tailscale API Token，僅在 Gateway 伺服器端需要，模板中不包含。

---

## 📜 License

MIT — 自由使用、修改、分享。詳見 [LICENSE](./LICENSE)。

---

**Status:** ✅ Production Ready
**Version:** v4.3 (Security Hardened Edition)
**Last Updated:** 2026-06-18

*「零成本不是夢想，是你的第二臺雲端電腦。」*


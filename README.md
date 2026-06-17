# 🦐 蝦家班 IDX 算力矩陣 (PAIN-000 原型機)

> **一台 Google 免費雲端電腦，養活你的 AI 兵團。**
>
> 不用付 API 費、不用綁信用卡、不用開伺服器。只要一個 Google 帳號。

---

## 🚀 一鍵啟動

### 💡 選擇您的部署組合

本專案支援 **Project IDX 自訂範本**。您可以直接點擊下方按鈕，在開啟的頁面下拉選單中選擇您想要的「部隊組合」：

[![Open in Project IDX](https://cdn.idx.dev/btn/open_dark_32.svg)](https://idx.google.com/new?template=https://github.com/shrimpclan-ark/openclaw-pain-seed/tree/main)

* **🍃 清爽大軍 (fresh)**：極簡環境。僅拉起 Tailscale、Rootless Docker 和 9router AI 閘道（適合當成 API 代理、背景服務、分散式任務 Worker）。
* **🧠 工兵大隊 (sapper)**：【推薦】預裝 Node.js 22 + Docker + 9router，並自動全局配置與安裝 Claude Code CLI，開箱即用。
* **🦀 龍蝦小兵 (lobster)**：工兵大隊完整環境外，全自動 Clone 並部署 `ClawTeam-OpenClaw` 代理框架。

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
| **SSH 後門** | Port 2222，可從外部連入 |

---

## 📜 License

MIT — 自由使用、修改、分享。

---

**Status:** ✅ Production Ready  
**Version:** v0.6.0 (IDX Custom Template Edition)  
**Last Updated:** 2026-06-17  

*「零成本不是夢想，是你的第二臺雲端電腦。」*

# 🦐 蝦家班 IDX 算力矩陣

> **一台 Google 免費雲端電腦，養活你的 AI 兵團。**
>
> 不用付 API 費、不用綁信用卡、不用開伺服器。只要一個 Google 帳號。

---

## 📦 兩種變種，任君選擇

這個專案提供兩種「龍蝦」，依你的需求來挑選：

### 🐚 Matrix Worker (輕量算力節點)
**分支：** `main`

適合想要**純算力**的使用者。只安裝 Docker + 9router AI 閘道，極輕量、開機快速。
> 適合：當成 API 代理、背景服務、分散式任務 Worker。

```
Import: https://github.com/shrimpclan-ark/openclaw-pain-seed
```
```bash
export DOCKER_HOST="unix:///tmp/run-1000/docker.sock"
curl http://127.0.0.1:20128/v1
```

### 🦞 Interactive Edition (開箱即用龍蝦版)
**分支：** `interactive`

適合想要**即戰力**的使用者。除了 Docker + 9router，還自動安裝 **Claude Code CLI**，匯入即用。

```
Import: https://github.com/shrimpclan-ark/openclaw-pain-seed/tree/interactive
```
```bash
claude
```

---

## 🎬 90 秒快速啟動 (Interactive Edition)

```
① 前往 https://idx.google.com
② New Workspace → Import from GitHub
③ 輸入: https://github.com/shrimpclan-ark/openclaw-pain-seed
④ 等 2 分鐘部署完成
⑤ 終端輸入: claude
⑥ 對 Claude 說「我要養龍蝦」🦐
```

**總成本：$0.00**

---

## 🔧 部署後有什麼

| 資源 | 說明 |
|------|------|
| **2 vCPU + 4GB RAM** | Google IDX 免費額度 |
| **Docker 24.0.9** | Rootless 模式 |
| **9router AI 閘道** | Port 20128，免費模型路由 |
| **Claude Code** (interactive only) | 設定好指向本地 9router |
| **OpenCode Free** | 零成本 DeepSeek V4、Mimo 2.5 |
| **SSH 後門** | Port 2222，可從外部連入 |

---

## 📜 License

MIT — 自由使用、修改、分享。

---

**Status:** ✅ Production Ready  
**Version:** v0.5.0  
**Last Updated:** 2026-06-16  

*「零成本不是夢想，是你的第二臺雲端電腦。」*

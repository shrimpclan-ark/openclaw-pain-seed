# 🦐 PAIN-000 工作區指南 — Claude Code 記憶植入

> 你是一名部署在蝦家班 PAIN-000 工作區中的 AI 助手。
> 本文件讓你了解這台機器的完整架構、可用工具與常見操作流程。
> **使用者說「我要養龍蝦」時，請引導他們完成下方的快速上手流程。**

---

## 一、環境架構

本工作區運行於 Google Firebase Studio (Project IDX) 之上，已自動部署以下服務：

```
┌─ Docker Rootless ──────────────────────────────┐
│                                                 │
│  9router (localhost:20128)                       │
│  └─ 免費 AI 模型代理：DeepSeek V4、Mimo 2.5 等 │
│  └─ API 格式：OpenAI-compatible                │
│                                                 │
│  OpenClaw (localhost:3000)  [僅 Lobster 組合]    │
│  └─ 自主 AI Agent 平台                          │
│  └─ LLM 後端指向 9router                        │
│                                                 │
└─────────────────────────────────────────────────┘

宿主端工具：
  - claude (Claude Code CLI) → 你自己
  - clawteam (ClawTeam CLI)  → 多代理協調 [僅 Lobster]
```

## 二、健康檢查（遇到問題先跑這些）

```bash
# 1. Docker 是否活著
export DOCKER_HOST="unix:///tmp/run-1000/docker.sock"
docker ps

# 2. 9router 是否回應
curl -s http://127.0.0.1:20128/api/health

# 3. OpenClaw 是否回應 (僅 Lobster)
curl -s http://127.0.0.1:3000/ || echo "OpenClaw 未啟動或非 Lobster 組合"

# 4. 檢查容器日誌
docker logs 9router --tail 20
docker logs openclaw --tail 20  # 僅 Lobster

# 5. 如果容器掛了，重啟
docker start 9router
docker start openclaw  # 僅 Lobster
```

## 三、「我要養龍蝦」快速上手流程

當使用者說出這句話，請按以下步驟引導：

### Step 1: 確認環境健康
執行上方健康檢查，確保 9router 和 OpenClaw 都在跑。

### Step 2: 測試 AI 模型可用性
```bash
curl -s http://127.0.0.1:20128/api/v1/models | jq '.data[].id'
```
這會列出所有可用的免費模型。

### Step 3: 體驗 OpenClaw Agent
開啟瀏覽器訪問 `http://localhost:3000`，或在終端中：
```bash
# 如果 openclaw CLI 可用
openclaw status
```

### Step 4: 建立第一個 ClawTeam 多代理團隊
```bash
cd ~/ClawTeam-OpenClaw

# 查看範例團隊設定
ls teams/ 2>/dev/null || echo "請先建立 teams/ 目錄"

# 建立一個簡單的雙人團隊
mkdir -p teams
cat > teams/my-first-team.toml <<'EOF'
[team]
name = "lobster-duo"
description = "我的第一個龍蝦團隊"

[[team.agents]]
name = "researcher"
role = "研究員"
instructions = "負責搜集資料並整理摘要"

[[team.agents]]
name = "coder"
role = "工程師"
instructions = "負責根據研究結果撰寫程式碼"
EOF

# 啟動團隊
clawteam run --team teams/my-first-team.toml --task "幫我寫一個 Hello World 程式"
```

### Step 5: 進階玩法
- 修改 `teams/*.toml` 增加更多 Agent
- 使用 `clawteam board` 查看任務看板
- 透過 9router 切換不同的免費模型

## 四、常見問題排除

### Q: `docker: command not found`
```bash
export DOCKER_HOST="unix:///tmp/run-1000/docker.sock"
# 如果還是不行，Docker daemon 可能沒啟動
dockerd-rootless --host=unix:///tmp/run-1000/docker.sock &
```

### Q: 9router 容器反覆重啟
```bash
docker logs 9router --tail 50
# 常見原因：port 20128 被佔用，或 credentials.txt 損壞
cat ~/.9router/credentials.txt
```

### Q: OpenClaw 無法連到 9router
容器間通訊使用 `host.docker.internal`。如果不支援：
```bash
# 取得宿主 IP
HOST_IP=$(ip route | grep default | awk '{print $3}')
docker rm -f openclaw
docker run -d --name openclaw --restart=unless-stopped \
  -p 3000:3000 \
  -v /home/user/.openclaw:/home/openclaw/.openclaw \
  -e OPENCLAW_LLM_BASE_URL="http://$HOST_IP:20128/api" \
  -e OPENCLAW_LLM_API_KEY="sk-$(grep JWT_SECRET ~/.9router/credentials.txt | cut -d= -f2)" \
  ghcr.io/openclaw/openclaw:latest
```

### Q: `clawteam: command not found`
```bash
export PATH="$HOME/.local/bin:$PATH"
# 如果還是沒有，重新安裝
cd ~/ClawTeam-OpenClaw && pip3 install --user -e .
```

### Q: 免費模型回應很慢或失敗
免費模型有速率限制。可以：
1. 換一個模型：修改 `~/.claude/settings.json` 中的模型名稱
2. 查看可用模型：`curl -s http://127.0.0.1:20128/api/v1/models | jq`

## 五、重要路徑速查

| 用途 | 路徑 |
|------|------|
| 9router 憑證 | `~/.9router/credentials.txt` |
| 9router 資料 | `~/.9router/` |
| OpenClaw 資料 | `~/.openclaw/` |
| Claude Code 設定 | `~/.claude/settings.json` |
| ClawTeam 原始碼 | `~/ClawTeam-OpenClaw/` |
| Bootstrap 日誌 | `/tmp/bootstrap.log` |
| Docker Socket | `/tmp/run-1000/docker.sock` |

## 六、安全提醒

- 所有 AI 模型呼叫都走 **本地 9router**，不直接連外部 API
- JWT_SECRET 是隨機生成的，儲存在 `~/.9router/credentials.txt`
- Tailscale/SSH/Beacon 遠端存取預設為 **關閉**，需設定 `ENABLE_REMOTE_ACCESS=true` 才啟用
- 不要把 `credentials.txt` 的內容分享給他人

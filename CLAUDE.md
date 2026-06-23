# 🦐 PAIN-000 工作區指南 — Claude Code 記憶植入 (v4.4 Battle-Tested)

> 你是一名部署在蝦家班 PAIN-000 工作區中的 AI 助手。
> 本文件讓你了解這台機器的完整架構、可用工具與常見操作流程。
> **使用者說「我要養龍蝦」時，請引導他們完成下方的快速上手流程。**
>
> ⚠️ **v4.4 先知導引**：本版本已內建所有已知陷阱的解決方案。
> 如果遇到問題，先查「四、十難列表」，再跑 `bash scripts/lobster-skillet.sh --fix`。

---

## 一、環境架構

本工作區運行於 Google Firebase Studio (Project IDX) 之上，已自動部署以下服務：

```
┌─ Docker Rootless (unix:///tmp/run-1000/docker.sock) ────────┐
│                                                              │
│  9router (localhost:20128)                                    │
│  └─ 免費 AI 模型代理：DeepSeek V4、Mimo 2.5 等              │
│  └─ API 格式：OpenAI-compatible                             │
│  └─ API Key：sk-9router（已預註冊到 SQLite DB）             │
│                                                              │
│  OpenClaw [僅 Lobster 組合]                                   │
│  ├─ Gateway  (localhost:3000)  → WebSocket，不回應 HTTP GET  │
│  ├─ Dashboard (localhost:18789) → HTTP，控制面板              │
│  └─ LLM 後端 → http://<9router-IP>:20128/api                │
│     ⚠️ 注意：baseUrl 必須含 /api，否則路徑錯誤              │
│                                                              │
└──────────────────────────────────────────────────────────────┘

宿主端工具：
  - claude (Claude Code CLI) → 你自己
  - clawteam (ClawTeam CLI)  → 多代理協調 [僅 Lobster]
```

### 關鍵差異（常見混淆點）

| 項目 | Port | 協定 | 用途 |
|------|------|------|------|
| 9router 管理面板 | 20128 | HTTP | 模型管理、API 代理 |
| OpenClaw Gateway | 3000 | **WebSocket** | Agent 通訊（curl 會回空） |
| OpenClaw Dashboard | **18789** | HTTP | 控制面板、聊天介面 |

---

## 二、快速健康檢查（遇到問題先跑這些）

```bash
# 0. 確保 Docker 環境變數
export DOCKER_HOST="unix:///tmp/run-1000/docker.sock"

# 1. Docker 容器狀態
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# 2. 9router 健康
curl -s http://127.0.0.1:20128/api/health

# 3. OpenClaw Dashboard（僅 Lobster）
curl -s -o /dev/null -w "HTTP %{http_code}\n" http://127.0.0.1:18789/

# 4. API Key 是否已註冊
docker exec 9router sh -c 'node -e "
  const db = require(\"better-sqlite3\")(\"/app/data/db/data.sqlite\");
  const keys = db.prepare(\"SELECT * FROM apiKeys WHERE isActive=1\").all();
  console.log(\"Active keys: \" + keys.length);
  keys.forEach(k => console.log(\"  - \" + k.key));
"'

# 5. 從容器內測試 LLM（驗證跨容器通訊）
NINE_IP=$(docker inspect 9router --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
docker exec openclaw sh -c "curl -s http://${NINE_IP}:20128/api/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer sk-9router' \
  -d '{\"model\":\"oc/deepseek-v4-flash-free\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":50}'" | head -1

# 6. 容器日誌（排查 crash）
docker logs 9router --tail 20
docker logs openclaw --tail 20
```

### 有問題？一鍵修復

```bash
bash scripts/lobster-skillet.sh --quick   # 快速診斷
bash scripts/lobster-skillet.sh --fix     # 互動修復
bash scripts/lobster-skillet.sh           # 完整重建
```

---

## 三、「我要養龍蝦」快速上手流程

當使用者說出這句話，請按以下步驟引導：

### Phase 1：確認環境就緒（60 秒）

```bash
export DOCKER_HOST="unix:///tmp/run-1000/docker.sock"
echo "=== Docker ===" && docker ps --format "table {{.Names}}\t{{.Status}}"
echo "=== 9router ===" && curl -s http://127.0.0.1:20128/api/health
echo "=== Dashboard ===" && curl -s -o /dev/null -w "HTTP %{http_code}\n" http://127.0.0.1:18789/
echo "=== Models ===" && curl -s http://127.0.0.1:20128/api/v1/models | python3 -c "import sys,json; [print('  ' + m['id']) for m in json.load(sys.stdin).get('data',[])]" 2>/dev/null
```

如果以上都正常（Docker 有 9router + openclaw 在跑，Dashboard 回 200，有可用模型），跳到 Phase 3。

### Phase 2：修復問題（如有）

```bash
# 如果 9router 或 openclaw 沒在跑
docker start 9router openclaw

# 如果 Dashboard 無回應（狀態不是 healthy）
bash scripts/lobster-skillet.sh --fix

# 如果沒有可用模型
curl -s http://127.0.0.1:20128/api/v1/models | python3 -m json.tool
```

### Phase 3：體驗 OpenClaw Dashboard

瀏覽器打開 Firebase Studio 的 18789 port 預覽：
```
https://18789-<你的workspace域名>/
```

或在終端中核准設備配對：
```bash
docker exec openclaw openclaw devices list
docker exec openclaw openclaw devices approve <DEVICE_ID>
```

### Phase 4：建立第一個 ClawTeam 多代理團隊

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
export PYTHONPATH="$HOME/.local/lib/python3.13/site-packages:$PYTHONPATH"
clawteam run --team teams/my-first-team.toml --task "幫我寫一個 Hello World 程式"
```

---

## 四、常見問題排除（十難列表）

> 以下 10 個陷阱是從實戰中蒸餾出來的，按遭遇頻率排序。

### 🔥 陷阱 1：`docker: command not found`
```bash
export DOCKER_HOST="unix:///tmp/run-1000/docker.sock"
# 如果還是不行，Docker daemon 可能沒啟動
dockerd-rootless --host=unix:///tmp/run-1000/docker.sock &
```

### 🔥 陷阱 2：9router 容器反覆重啟
```bash
docker logs 9router --tail 50
# 常見原因：port 20128 被佔用，或 credentials.txt 損壞
cat ~/.9router/credentials.txt
# 解決：砍掉重啟
docker rm -f 9router
# 然後重新執行 install.sh 或 lobster-skillet.sh
```

### 🔥 陷阱 3：OpenClaw 容器 crash 迴圈 — `Unsafe fallback temp dir`
**根因：** 容器內 `/home/node/.openclaw` 是 root 所有，但 OpenClaw 以 node（UID 1000）執行。
**解法：** 不能直接 run 官方映像，必須自建映像（v4.4 已自動處理）
```bash
# 不能這樣（會 crash）：
docker run ghcr.io/openclaw/openclaw:latest  # ❌

# 必須這樣：
docker run openclaw:local  # ✅ （預先 chown + COPY 設定的映像）
```

### 🔥 陷阱 4：OpenClaw 容器 UID 映射 — `EACCES: permission denied`
**根因：** Rootless Docker 有使用者命名空間重新映射，主機 user 的檔案容器內寫不了。
**解法：** 捨棄 volume 掛載，把設定 COPY 進映像內（v4.4 已自動處理）

### 🔥 陷阱 5：9router 從容器連線需要 API key — `401 Unauthorized`
**根因：** 9router 有 `REQUIRE_API_KEY=true`，從容器 IP 訪問必須帶註冊過的 key。
**解法：** 註冊 `sk-9router` key 到 DB（v4.4 已自動處理）
```bash
# 手動註冊（如果自動註冊失敗）
docker exec 9router sh -c 'node -e "
  const db = require(\"better-sqlite3\")(\"/app/data/db/data.sqlite\");
  db.prepare(\"INSERT OR REPLACE INTO apiKeys (id, key, name, machineId, isActive, createdAt) VALUES (?, ?, ?, ?, ?, ?)\")
    .run(1, \"sk-9router\", \"openclaw\", \"\", 1, new Date().toISOString());
  console.log(\"OK\");
"'
```

### 🔥 陷阱 6：OpenClaw baseUrl 缺少 `/v1` 或路徑錯誤
**根因：** OpenClaw 的 `openai-completions` 模式會自動組合路徑 `baseUrl/chat/completions`，但 9router 的端點是 `/api/v1/chat/completions`。如果 baseUrl 只寫 `/api`，會打到錯誤的 401 端點。
```bash
# ❌ 錯誤
"baseUrl": "http://172.17.0.3:20128" 或 "http://172.17.0.3:20128/api"
# ✅ 正確
"baseUrl": "http://172.17.0.3:20128/api/v1"
```

### 🔥 陷阱 7：Firebase Studio 反向代理 — `Unable to forward request`
**根因：** Firebase Studio 的 proxy 需要 HTTP 握手成功，且 Dashboard 需要 `bind: lan` + `allowedOrigins`。
**解法：** 雙埠映射（3000 + 18789）+ config 中設 `bind: lan` + `allowedOrigins`（v4.4 已自動處理）

### 🔥 陷阱 8：ClawTeam CLI — `ModuleNotFoundError: No module named 'clawteam'`
**根因：** NixOS 的 Python 不走標準的 `--user` site-packages 路徑。
**解法：** 手動指定 PYTHONPATH（v4.4 已自動處理）
```bash
export PYTHONPATH="$HOME/.local/lib/python3.13/site-packages:$PYTHONPATH"
```

### 🔥 陷阱 9：Docker build cache 導致設定沒更新
**根因：** 改變 config 後重建，因 cache layer 沒過期，映像內容還是舊的。
**解法：** 重建前先確認 config 內容正確：
```bash
python3 -c "import json; cfg=json.load(open('/tmp/openclaw-config/openclaw.json')); print(cfg['models']['providers']['9router']['baseUrl'])"
rm -rf /tmp/.openclaw && cp -r /tmp/openclaw-config /tmp/.openclaw
docker build --no-cache -t openclaw:local -f /tmp/Dockerfile.openclaw /tmp/.
```

### 🔥 陷阱 10：每次重啟需重新裝置配對
每次容器重建後，瀏覽器的控制台 token 會失效，需重新核准。
**解法：** 瀏覽器按 F5 → 跳出 device ID → `docker exec openclaw openclaw devices approve <ID>`

---

## 五、重要路徑速查

| 用途 | 路徑 |
|------|------|
| 9router 憑證 | `~/.9router/credentials.txt` |
| 9router 資料 | `~/.9router/` |
| 9router API Key DB | `docker exec 9router node -e "db=require('better-sqlite3')('/app/data/db/data.sqlite')"` |
| OpenClaw 資料 | `~/.openclaw/` |
| OpenClaw Gateway 日誌 | `docker logs openclaw` |
| OpenClaw Dashboard | `http://localhost:18789/` |
| Claude Code 設定 | `~/.claude/settings.json` |
| ClawTeam 原始碼 | `~/ClawTeam-OpenClaw/` |
| Bootstrap 日誌 | `/tmp/bootstrap.log` |
| Docker Socket | `/tmp/run-1000/docker.sock` |
| 9router 日誌 | `docker logs 9router` |
| 龍蝦錦囊 | `scripts/lobster-skillet.sh` |

---

## 六、安全提醒

- 所有 AI 模型呼叫都走 **本地 9router**，不直接連外部 API
- JWT_SECRET 是隨機生成的，儲存在 `~/.9router/credentials.txt`
- Tailscale/SSH/Beacon 遠端存取預設為 **關閉**，需設定 `ENABLE_REMOTE_ACCESS=true` 才啟用
- 不要把 `credentials.txt` 的內容分享給他人
- `sk-9router` 是內建 API key，不要外洩

---

## 附錄：快速指令大全

```bash
# 完整健康檢查
export DOCKER_HOST="unix:///tmp/run-1000/docker.sock"
echo "Docker: $(docker ps -q | wc -l) containers"
echo "9router: $(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:20128/api/health)"
echo "Dashboard: $(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:18789/)"
echo "9router IP: $(docker inspect 9router --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')"

# 查看可用免費模型
curl -s http://127.0.0.1:20128/api/v1/models | jq -r '.data[].id' | grep -E "free|flash"

# 測試 LLM
curl -s http://127.0.0.1:20128/api/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-9router" \
  -d '{"model":"oc/deepseek-v4-flash-free","messages":[{"role":"user","content":"hi"}],"max_tokens":100}'

# 查看裝置配對
docker exec openclaw openclaw devices list

# 核准裝置配對
docker exec openclaw openclaw devices approve <DEVICE_ID>
```

---

## 注意：這個 Workspace 的特殊身分

如果 workspace 內有 `IDENTITY.md`、`SOUL.md`、`USER.md` 等檔案，
代表它是某人（如論壇法友）的 **數位孿生**。

**請先閱讀這些檔案再開始對話，了解主人的身份與立場。**
這不是一般的 OpenClaw Agent，而是承載了特定人物背景與思想的數位分身。

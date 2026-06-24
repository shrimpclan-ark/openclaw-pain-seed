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

### 🔥 IDX 部署十難 (The 10 Traps)

在將 OpenClaw 部署至 Rootless Docker 與 Firebase Studio 的過程中，我們曾經歷了十個致命陷阱。現在於 **v4.5.0** 這些陷阱皆已被永久封印。以下作為歷史除錯紀錄與維護參考：

1. **Trap 1: 官方映像 UID 問題 (`EACCES: permission denied`)**
   - **根因：** Rootless Docker 的 volume 掛載會導致容器內的 node (UID 1000) 無法寫入。
   - **解法 (v4.4)：** 捨棄外部檔案掛載，動態 `docker build` 一個自建的 `openclaw:local` 映像，把設定檔與權限全部在映像內處理完畢。

2. **Trap 2: 容器 Crash 迴圈 (`Unsafe fallback temp dir`)**
   - **根因：** `/home/node/.openclaw` 因權限問題無法寫入，導致系統崩潰。
   - **解法 (v4.4)：** 在自建映像中 `chown -R 1000:1000` 並指定 `ENV OPENCLAW_TEMP_DIR=/tmp/openclaw`。

3. **Trap 3: API Key 未註冊 (`401 Unauthorized`)**
   - **根因：** 從 OpenClaw 連接 `9router` 必須帶有資料庫中有效的金鑰。
   - **解法 (v4.4)：** 於 `dev.nix` 啟動時自動執行 SQLite 寫入指令預先註冊 `sk-9router`。

4. **Trap 4: Dashboard 來源不允許 (`Unable to forward request`)**
   - **根因：** Firebase Studio 的反向代理機制會驗證 origin。
   - **解法 (v4.4)：** 設定 `allowedOrigins: ["*"]` 以及 `bind: lan`。

5. **Trap 5: 雙埠映射問題**
   - **根因：** 忘記暴露 Gateway Port 導致控制台能開但後端 API 不通。
   - **解法 (v4.4)：** `docker run` 同時開放 `-p 3000:3000 -p 18789:18789`。

6. **Trap 6: 對話資料遺失 (IDX 重啟失憶)**
   - **根因：** 為了解決 Trap 1 移除了外部掛載，導致 IDX 每次喚醒 VM `docker rm` 後，資料隨之灰飛煙滅。
   - **解法 (v4.5)：** 引入 Docker 內部管理的 Named Volume (`-v openclaw-data:/home/node/.openclaw`)。如此既無權限問題，又能讓對話與狀態實現「永生」。

7. **Trap 7: ClawTeam CLI (`ModuleNotFoundError`)**
   - **根因：** NixOS 預設不讀取 user site-packages 路徑。
   - **解法 (v4.4)：** 自動注入 `export PYTHONPATH="$HOME/.local/lib/python3.13/site-packages:$PYTHONPATH"`。

8. **Trap 8: 裝置配對不持久**
   - **根因：** 每次容器重建，Dashboard 配對的 token 都會被洗掉，導致每次重啟都要重新 `approve` 裝置。
   - **解法 (v4.5)：** 由於 Trap 6 使用了 Named Volume，授權狀態得以保留，現在只需初次配對一次即可。

9. **Trap 9: 9router IP 浮動 (`Connection Refused`)**
   - **根因：** 原本使用 `docker inspect` 抓取 172.x.x.x，但重啟後 9router IP 可能改變，而 OpenClaw 若讀取到舊的 Volume 記錄就會連線失敗。
   - **解法 (v4.5)：** 建立自訂 Docker 網路 `docker network create pain-net`，並讓兩個容器互相加入。從此只需將 baseUrl 寫死為 `http://9router:20128`，完美靠 DNS 解析。

10. **Trap 10: 無聲的 401 授權失敗 (`baseUrl` 缺少 `/v1`)**
    - **根因：** OpenClaw 的 `openai-completions` 模式發送請求時只會自動附加 `/chat/completions`。若 `baseUrl` 寫成 `.../api`，會打到 9router 根本不存在的 `.../api/chat/completions` 導致直接退回 401，且不留任何日誌。
    - **解法 (v4.4.1)：** 將 `baseUrl` 精準設定為 `http://9router:20128/api/v1`，湊出正確的端點。

11. **Trap 11: 容器重啟後自訂網路斷開 (`Network Connection Error`)**
    - **根因：** 若僅用 `docker network connect` 指令將運行中的容器加入網路，當容器重啟 (restart) 時該連接就會遺失。
    - **解法 (v4.5.0)：** 將網路綁定改為原生啟動參數 `docker run --network pain-net`，確保容器每次重啟都自動在該網路內。若使用舊版，可執行 `scripts/openclaw-reconnect.sh` 自動修復連線。

12. **Trap 12: 瀏覽器 Token 快取與重新配對**
    - **根因：** 雖然 Volume 保存了 `gateway.auth.token`，但 IDX 每次重啟可能會分配不同的外部預覽 URL，導致瀏覽器端 WebSocket 憑證失效需要重連。
    - **解法 (v4.5.0)：** `openclaw-reconnect.sh` 腳本會從容器內抽取出永久 Token，並產生帶有 `#token=xxx` 的捷徑 URL，點擊即可無縫登入。

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

# 🦐 openclaw-pain-seed v4.4 晉版計畫

> **結論**：lobster-skillet.sh 是優秀的戰後急救包，但真正的問題在上游 — `dev-lobster.nix` 部署 OpenClaw 的方式從頭就是錯的。**不修 nix，每個新 workspace 都會重走十難。**

---

## 一、Bug 溯源：dev-lobster.nix → 十難

| dev-lobster.nix 的寫法 | 導致的陷阱 | 正確寫法 |
|---|---|---|
| `ghcr.io/openclaw/openclaw:latest` 直接跑 | 陷阱 1, 2, 3（權限地獄） | 預建自定映像，COPY config + chown |
| `-v "$OC_DATA_DIR:/home/openclaw/.openclaw"` | 陷阱 2, 4（UID 映射 + 互動 TTY） | 捨棄 volume，設定內建映像 |
| `-p 3000:3000`（只開 3000） | 陷阱 5（Port 混淆） | `-p 3000:3000 -p 18789:18789` |
| `host.docker.internal:20128` | 陷阱 9 的前置條件（容器間 IP 路由） | `docker inspect` 取 9router IP |
| `sk-$JWT_SECRET`（未註冊到 DB） | 陷阱 9（401 Unauthorized） | `INSERT INTO apiKeys` 預註冊 `sk-9router` |
| 無 `bind: lan` / `allowedOrigins` | 陷阱 6, 7（Firebase 反代阻擋） | config 中設定 `bind: lan` + origins |
| 無 entrypoint 覆寫 | 陷阱 4（Interactive TTY） | `sh -c "openclaw gateway run --force"` |
| `pip3 install --user`（無 PYTHONPATH） | 陷阱 8（NixOS Python path） | 加 `PYTHONPATH` 到 `.bashrc` |

**8/10 的陷阱直接源自 nix 模板的寫法。** lobster-skillet.sh 是事後的急救，但如果 nix 一開始就寫對，Claude Code 根本不需要踩坑。

---

## 二、修改範圍

### 📁 檔案清單

| 檔案 | 動作 | 說明 |
|------|------|------|
| `envs/dev-lobster.nix` | ✏️ **重寫 OpenClaw 部署段** | 核心修復：自建映像 + API key 預註冊 + 雙埠 + bind:lan |
| `CLAUDE.md` | ✏️ **大幅更新** | 加入十難 SOP、正確的架構圖、陷阱列表 |
| `scripts/lobster-skillet.sh` | ✅ **新增** | 小兵的錦囊妙計，作為 post-deploy 診斷/修復工具 |
| `install.sh` | ✏️ **加入 API key 步驟** | 加 Step 5.5：預註冊 sk-9router 到 DB |
| `README.md` | ✏️ 版本號更新 | v4.3 → v4.4 (Lobster Battle-Tested Edition) |

### 🔑 dev-lobster.nix 關鍵修改

```diff
  # 5. Deploy OpenClaw Platform
- docker pull ghcr.io/openclaw/openclaw:latest
- docker run -d \
-   --name openclaw \
-   -p 3000:3000 \
-   -v "$OC_DATA_DIR:/home/openclaw/.openclaw" \
-   -e OPENCLAW_LLM_BASE_URL="http://host.docker.internal:20128/api" \
-   -e OPENCLAW_LLM_API_KEY="sk-$JWT_SECRET" \
-   ghcr.io/openclaw/openclaw:latest

+ # 5a. 預註冊 API key（陷阱 #9 修復）
+ sleep 3
+ docker exec 9router sh -c 'node -e "
+   const db = require(\"better-sqlite3\")(\"/app/data/db/data.sqlite\");
+   db.prepare(\"INSERT OR REPLACE INTO apiKeys (id, key, name, ...) VALUES (?, ?, ?, ?, ?, ?)\")
+     .run(1, \"sk-9router\", \"openclaw\", \"\", 1, new Date().toISOString());
+ "' || true
+
+ # 5b. 取得 9router 容器 IP（避免 host.docker.internal 問題）
+ NINE_IP=$(docker inspect 9router --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
+
+ # 5c. 產生 OpenClaw config（含 bind:lan + allowedOrigins + trustedProxies）
+ mkdir -p /tmp/openclaw-config
+ cat > /tmp/openclaw-config/openclaw.json <<OCEOF
+ { ... baseUrl: "http://${NINE_IP}:20128/api", apiKey: "sk-9router", bind: "lan" ... }
+ OCEOF
+
+ # 5d. 自建映像（繞過 UID 映射 + 權限問題）
+ cat > /tmp/Dockerfile.openclaw <<'DEOF'
+ FROM ghcr.io/openclaw/openclaw:latest
+ USER root
+ RUN chown -R 1000:1000 /home/node/.openclaw /home/node/.config 2>/dev/null; true
+ COPY .openclaw /home/node/.openclaw
+ RUN chown -R 1000:1000 /home/node/.openclaw
+ USER node
+ ENV OPENCLAW_TEMP_DIR=/tmp/openclaw
+ DEOF
+
+ cp -r /tmp/openclaw-config /tmp/.openclaw
+ docker build -t openclaw:local -f /tmp/Dockerfile.openclaw /tmp/.
+
+ # 5e. 雙埠啟動 + 正確 entrypoint
+ docker run -d --name openclaw --restart=unless-stopped \
+   -p 3000:3000 -p 18789:18789 \
+   -e OPENCLAW_TEMP_DIR="/tmp/openclaw" \
+   openclaw:local sh -c "openclaw gateway run --force"
```

### 🔑 CLAUDE.md 關鍵修改

```diff
  ## 一、環境架構
- │  OpenClaw (localhost:3000)  [僅 Lobster 組合]    │
+ │  OpenClaw Gateway (localhost:3000)  [WebSocket]   │
+ │  OpenClaw Dashboard (localhost:18789) [HTTP]       │

  ## 三、「我要養龍蝦」
- ### Step 1: 確認環境健康
- 執行上方健康檢查，確保 9router 和 OpenClaw 都在跑。
+ ### ⚡ Phase 1：快速診斷（60 秒）
+ ```bash
+ export DOCKER_HOST="unix:///tmp/run-1000/docker.sock"
+ echo "=== Docker ===" && docker ps --format "table {{.Names}}\t{{.Status}}"
+ echo "=== 9router ===" && curl -s http://127.0.0.1:20128/api/health
+ echo "=== Dashboard ===" && curl -sI http://127.0.0.1:18789/ | head -1
+ ```
+
+ ### 🛠️ Phase 2：如果有問題
+ ```bash
+ bash scripts/lobster-skillet.sh --fix
+ ```
+
+ ## 四、常見問題排除（十難列表）
+ ### 🔥 陷阱 1-10: ...（完整列表）
```

---

## 三、lobster-skillet.sh 的定位

小兵的錦囊妙計**不應該被丟掉**，而是收編為 `scripts/lobster-skillet.sh`：

| 用途 | 說明 |
|------|------|
| `bash scripts/lobster-skillet.sh` | 完整養殖（nix 部署失敗時的 fallback） |
| `bash scripts/lobster-skillet.sh --quick` | 快速健康檢查 |
| `bash scripts/lobster-skillet.sh --fix` | 互動式修復（Claude Code 可調用） |

**但它有 2 個 bug 需要修：**

1. **L66-84：模式選擇在函數定義之前**（`phase_quickcheck` 在 L90 才定義，但 L70 就呼叫了）
2. **L85：有一個孤立的 `EOF`** 應該刪除

---

## 四、為什麼不只放 skillet

> 如果只放 lobster-skillet.sh 而不修 nix：
> - 每個新 workspace 的 Claude Code 仍然會先踩到 nix 部署的錯誤 OpenClaw
> - 然後才發現需要跑 skillet 來修復
> - 等於讓每個小兵都重走一遍十難的前 4 關
>
> 修了 nix = **預防**。放 skillet = **急救**。兩者都要做。

---

## 五、版本計畫

```
v4.3  (current)  — Security Hardened Edition
v4.4  (target)   — Lobster Battle-Tested Edition
                   ├── dev-lobster.nix: 正確部署 OpenClaw
                   ├── CLAUDE.md: 十難 SOP + 正確架構圖
                   ├── scripts/lobster-skillet.sh: 診斷/修復工具
                   ├── install.sh: API key 預註冊
                   └── README.md: 版本更新
```

> [!IMPORTANT]
> 探長請確認：
> 1. 是否同意晉版到 v4.4？
> 2. `pain-merchant-generator-lite` 的模板也要同步更新嗎？
> 3. lobster-skillet.sh 的兩個 bug（函數順序 + 孤立 EOF）我直接修掉？

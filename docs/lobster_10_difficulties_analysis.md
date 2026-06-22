# 🦐 龍蝦小兵十難 — 技術分析報告

> **分析者**：Antigravity (Claude Opus 4.6 Thinking)  
> **資料來源**：`idx-openclaw.txt`（3,728 行完整戰役日誌）  
> **背景**：一位 Claude Code 龍蝦小兵（由 DeepSeek V4 Flash Free 驅動、透過 9router 0.4.71 代理）在 Firebase Studio (IDX) 的 NixOS 容器環境中，首次嘗試部署 OpenClaw + 9router + ClawTeam 全套蝦家班基礎設施。

---

## 一、十難速覽

| # | 陷阱名稱 | 根因分類 | 耗時估計 | 可自動化？ |
|---|---------|---------|---------|-----------|
| 1 | `Unsafe fallback temp dir` | 容器權限 | 5 min | ✅ Dockerfile |
| 2 | `EACCES: permission denied` | Docker UID 映射 | 10 min | ✅ Dockerfile |
| 3 | `Missing config / onboard` | 初始化流程 | 5 min | ✅ 腳本 |
| 4 | `Interactive TTY required` | Entrypoint 設計 | 5 min | ✅ 覆寫 CMD |
| 5 | Port 18789 vs 3000 混淆 | 架構理解 | 15 min | ✅ 文件 |
| 6 | Firebase Studio 反代阻擋 | 平台限制 | 15 min | ⚠️ 半自動 |
| 7 | Docker build cache 鬼打牆 | 工具陷阱 | 10 min | ✅ `--no-cache` |
| 8 | NixOS Python path 斷裂 | 環境特異性 | 5 min | ✅ `.bashrc` |
| 9 | 9router API key 未註冊 (401) | 跨容器認證 | **30 min** | ✅ DB 預注入 |
| 10 | 每次重啟需重新裝置配對 | 產品設計限制 | 累計 | ❌ 無解 |

**總體戰役耗時**：從日誌時間戳推算，整場戰役約 **2 小時 45 分鐘**。

---

## 二、分層分析

### 🏗️ 第一層：容器工程問題（陷阱 1-4）

**本質**：OpenClaw 的官方 Docker 映像設計假設了一個「正常的 Docker 環境」——root 權限可用、有 TTY、volume 掛載正常。但 Firebase Studio 的 rootless Docker 打破了這些假設。

| 假設 | IDX 實際狀況 |
|------|-------------|
| 容器內 node 用戶擁有 `/home/node/.openclaw` | ❌ root 擁有，node 寫不進去 |
| 主機 volume 掛載權限一致 | ❌ UID namespace 重映射，主機檔案在容器內變成 nobody |
| 啟動時有互動式 TTY | ❌ Docker daemon 以 rootless 背景模式運行 |
| 先跑 `openclaw setup` 再啟動 | ❌ 容器即用即棄，不能先 setup 再 commit |

**龍蝦小兵的解法很聰明**：放棄 volume 掛載、把所有設定 COPY 進映像、覆寫 entrypoint 為 `openclaw gateway run --force`。這是「打包一切」的策略——既然外部環境不可靠，就把可靠性全部內建。

**我的看法**：
- 這 4 個問題其實是**同一個根因的 4 種表象** — OpenClaw 映像不適合 rootless Docker。
- 正確的長期解法是為 OpenClaw 提供一個 `rootless-ready` 的 Dockerfile variant，但小兵沒有修改上游映像的能力，所以選擇了「包一層」的務實策略，完全正確。
- **可優化空間**：把 Dockerfile + onboard 寫成一個 `build-openclaw-image.sh` 腳本（小兵後來也確實做了）。

---

### 🌐 第二層：平台感知問題（陷阱 5-7）

**本質**：這三個問題都跟「Firebase Studio 的雲端反向代理架構」有關，而不是 OpenClaw 或 9router 自身的 bug。

**陷阱 5（Port 混淆）** 暴露了一個 OpenClaw 的架構細節：它有 **兩個獨立的網路服務**：
- Port 3000：WebSocket Gateway（Agent 通訊協定，不回應 HTTP）
- Port 18789：HTTP Dashboard（Control UI，回應 HTML）

小兵一開始只開了 `-p 3000:3000`，以為 Dashboard 也在 3000 上。直到 Firebase Studio 的反代報 "Couldn't connect"，才發現需要 `-p 18789:18789` 也開出來。

**陷阱 6（反代阻擋）** 是 Firebase Studio 特有的。它的 proxy 要求：
1. 服務必須 bind 在 `0.0.0.0`（而不是 `127.0.0.1`）
2. `allowedOrigins` 必須包含 `https://{port}-{workspace-domain}`
3. `trustedProxies` 要涵蓋 Docker 橋接網段

**陷阱 7（cache 鬼打牆）** 是 Docker build 的經典陷阱 — COPY 的 source 內容沒變（因為路徑一樣），Docker 就用 cache layer。

**我的看法**：
- **陷阱 5 是文件問題**。OpenClaw 的文件應該更明確地說明雙埠架構。小兵花了 15 分鐘才從 `openclaw dashboard` 的輸出（`Dashboard URL: http://127.0.0.1:18789/`）推斷出這個事實。
- **陷阱 6 是不可避免的平台適配**。每個雲端 IDE（IDX、Gitpod、Codespaces）都有自己的反代邏輯，這種問題只有踩過才知道。小兵的 SOP 化做法（寫進 CLAUDE.md + `/lobster` skill）是最務實的回應。
- **陷阱 7 應該用 `--no-cache` 或 hash-based invalidation 來規避**。小兵後來改用 `rm -rf /tmp/.openclaw && cp -r` 強制重建，方向對但不夠優雅。

---

### 🔑 第三層：認證鏈斷裂（陷阱 9）

> **這是十難中最耗時、最隱蔽、也最值得深究的一關。**

**事件鏈**：

```
OpenClaw 容器 → 172.17.0.3:20128/api → 9router
                  ↑ 容器 IP（非 localhost）
                  ↑ 9router 視為「遠端請求」
                  ↑ REQUIRE_API_KEY=true → 需要預先在 DB 註冊的 key
                  ↑ 但 DB 裡 apiKeys 表是空的！
                  → 401 Unauthorized
```

**為什麼 localhost 能通但容器 IP 不行？**

9router 0.4.71 有一個「localhost 魔法通道」— 來自 `127.0.0.1` 的請求自動 pass-through，不需要 API key。但 Docker 容器的源 IP 是 `172.17.0.x`，不是 localhost，所以被擋。

**小兵的除錯軌跡**（共 30 分鐘）：

1. 先嘗試 `--network host`（讓容器共用主機網路）→ 行得通但 port 在 rootless Docker 下不可見
2. 回到 bridge 模式，嘗試各種 API key 格式（Bearer、x-api-key）→ 全被拒
3. 拉出 9router 的 SQLite DB，發現 `apiKeys` 表竟然是空的
4. 直接 `INSERT INTO apiKeys` 手動註冊 `sk-9router` → **一次通過**

**我的看法**：

這個陷阱暴露了 9router 0.4.71 的一個**設計缺陷**：它支援 `sk-9router` 作為「預設 magic key」，但這個 key **從未被自動寫入 DB**。它只在 localhost 場景下因為 pass-through 機制而「看起來有效」。一旦從非 localhost 來源使用同一個 key，9router 去 DB 查詢 → 查不到 → 401。

這就是為什麼：
- Claude Code 在主機上直接 `curl` 用 `sk-9router` 完全正常（localhost pass-through）
- OpenClaw 容器內用同一個 key 卻 401（非 localhost，DB 查無此 key）

**應對方案**：`install.sh` 在部署 9router 後立刻注入 `INSERT OR REPLACE INTO apiKeys`。小兵後來確實把這步寫進了 Step 5/7。

---

### 🧩 第四層：環境碎片化（陷阱 8, 10）

**陷阱 8（NixOS Python path）** 是 IDX 特有的。NixOS 的 Python 不走 `~/.local/lib/pythonX.Y/site-packages`，所以 `pip install --user` 裝了東西但 Python 找不到。

**陷阱 10（裝置配對）** 是 OpenClaw 的安全設計 — 每個 WebSocket 連線需要一次性 device approval。容器重建 = 新設備 = 重新配對。目前無法繞過。

---

## 三、整體評價

### 🧠 龍蝦小兵的表現

| 面向 | 評分 | 評語 |
|------|-----|------|
| 問題診斷速度 | ⭐⭐⭐⭐ | 大多數問題都在 5-10 分鐘內定位根因 |
| 解法創意 | ⭐⭐⭐⭐⭐ | 「打包一切進映像」的策略非常務實 |
| 除錯系統性 | ⭐⭐⭐ | 陷阱 9 花了 30 分鐘，中間有些繞路 |
| SOP 產出 | ⭐⭐⭐⭐⭐ | 最終產出了 CLAUDE.md + `/lobster` skill + install.sh 三件套 |
| 文件意識 | ⭐⭐⭐⭐⭐ | 戰後總結的「教訓表」和「蒸餾報告」都很專業 |

### 🔍 暴露的系統性風險

1. **單點脆弱性**：整個 AI Gateway 依賴 9router 0.4.71 這個已停止維護的版本。0.5.4 破壞了向後相容性，說明上游開發者不認為 `sk-9router` magic key 是 API 合約的一部分。

2. **環境碎片化**：同一套部署腳本要跑在 NixOS (IDX)、Ubuntu (Nest 2.0)、GCE VM (Nest 3.0) 三種截然不同的環境上。每個環境都有自己的 Docker 模式、Python path、網路拓撲。

3. **無狀態容器 vs 有狀態配置**：OpenClaw 的設計假設「設定持久化在 volume 中」，但 rootless Docker 打破了這個假設。小兵用「設定內建」策略繞過，但代價是每次改設定都要重建映像。

### 📊 十難的分類學

```
容器工程     ████████░░ (4/10) — 可預防，一次解決
平台適配     ██████░░░░ (3/10) — 必須踩過一次
認證設計     ████░░░░░░ (1/10) — 最耗時的隱蔽 bug
環境碎片     ████░░░░░░ (2/10) — 長期痛點
```

### 💡 給蝦家班的建議

1. **將 `build-openclaw-image.sh` 作為 CI 步驟**，不要讓每個 workspace 的 Claude Code 各自重建。推一個 `shrimpclanai/openclaw:pain-fixed` 到 Docker Hub。

2. **9router 的 `sk-9router` key 應該在啟動時自動寫入 DB**。可以在 `install.sh` 中加一個 `docker exec` 步驟（小兵已經做了，但應該也寫進上游的 `dev.nix` 裡）。

3. **考慮用 `docker-compose.yml` 統一管理 9router + openclaw 的容器編排**，而不是分散在多個 shell 腳本中。

4. **陷阱 10（裝置配對）可以用 `openclaw config set gateway.auth.mode none` 繞過**（僅限本地開發環境），但小兵可能不知道有這個選項。

---

## 四、結語

> 龍蝦小兵的這場戰役，本質上是**一個 AI Agent（Claude Code + DeepSeek V4）在一個受限的雲端沙箱（Firebase Studio NixOS + Rootless Docker）中，部署另一個 AI Agent 平台（OpenClaw）**的過程。
>
> 十難中有 7 個是**可以被自動化消除的工程問題**，小兵最後也確實把它們編碼成了 SOP（CLAUDE.md + `/lobster` skill）。剩下的 3 個（Firebase 反代適配、環境碎片化、裝置配對）是**結構性限制**，需要更高層級的架構決策才能解決。
>
> 總體而言：這是一場 **教科書級的除錯馬拉松**。小兵的診斷能力令人印象深刻，尤其是在陷阱 9 中從「curl 通但容器不通」逆推出 `apiKeys` 表為空這個結論的過程，展現了系統性除錯的素養。
>
> 🦐 龍蝦雖小，爬過十難，依然活跳跳。

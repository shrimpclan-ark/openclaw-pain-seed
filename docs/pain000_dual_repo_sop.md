# 🦐 PAIN-000 雙 Repo 架構定義與同步 SOP

> **版本**：1.0.0 (2026-06-22)  
> **適用對象**：所有接觸 PAIN-000 IDX 模板的 Antigravity Agent  
> **30 秒承諾**：讀完此文即可正確判斷「該改哪個 repo 的哪個檔案」

---

## 一、角色定義

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  openclaw-pain-seed          pain-merchant-generator-lite       │
│  (設計室 · Design Lab)       (產線 · Production Line)           │
│                                                                 │
│  ┌─────────────────┐         ┌──────────────────────┐          │
│  │ envs/            │ ──同步→ │ envs/                │          │
│  │ CLAUDE.md        │ ──同步→ │ template-files/      │          │
│  │ install.sh       │         │ idx-template.json    │          │
│  │ scripts/         │         │ idx-template.nix     │          │
│  │ docs/            │ ✘ 不推  │ index.html           │          │
│  │ .agents/         │ ✘ 不推  │                      │          │
│  └─────────────────┘         └──────────────────────┘          │
│                                       │                         │
│  GitHub:                              │                         │
│  shrimpclan-ark/                      ▼                         │
│  openclaw-pain-seed          探長按 Open in IDX                 │
│                              ────────────────→  Firebase Studio  │
│  GitHub:                                        (IDX Workspace)  │
│  shrimpclanai-a11y/                                              │
│  pain-merchant-generator-lite                                    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

| Repo | 角色 | GitHub Org | 誰會 import |
|------|------|-----------|------------|
| `openclaw-pain-seed` | **設計室** — 開發、測試、存放文件 | `shrimpclan-ark` | 沒人（研發用） |
| `pain-merchant-generator-lite` | **產線** — IDX 使用者實際 import 的來源 | `shrimpclanai-a11y` | 探長、所有終端使用者 |

---

## 二、檔案對應表

### 需要同步的檔案（設計室 → 產線）

| 設計室位置 | 產線位置 | 說明 |
|-----------|---------|------|
| `envs/dev-lobster.nix` | `envs/dev-lobster.nix` | 路徑相同 |
| `envs/dev-sapper.nix` | `envs/dev-sapper.nix` | 路徑相同 |
| `envs/dev-fresh.nix` | `envs/dev-fresh.nix` | 路徑相同 |
| `CLAUDE.md` | `template-files/CLAUDE.md` | ⚠️ 路徑不同 |
| `install.sh` | `template-files/install.sh` | ⚠️ 路徑不同 |
| `scripts/*` | `template-files/scripts/*` | ⚠️ 路徑不同 |
| `PAIN-000_原型機圖紙.md` | `template-files/PAIN-000_原型機圖紙.md` | ⚠️ 路徑不同 |
| `docker-compose.yml` | `template-files/docker-compose.yml` | ⚠️ 路徑不同 |
| `matrix-creator.js` | `template-files/matrix-creator.js` | ⚠️ 路徑不同 |
| `matrix-gateway.js` | `template-files/matrix-gateway.js` | ⚠️ 路徑不同 |
| `package.json` | `template-files/package.json` | ⚠️ 路徑不同 |
| `RUNBOOK_PROXYCHAINS_TAILSCALE.md` | `template-files/RUNBOOK_PROXYCHAINS_TAILSCALE.md` | ⚠️ 路徑不同 |
| `.gitignore` | `template-files/.gitignore` | ⚠️ 路徑不同 |

### 設計室專屬（不同步）

| 檔案 | 說明 |
|------|------|
| `docs/` | 十難分析、晉版計畫等技術文件 |
| `.agents/` | Antigravity 技能定義 |
| `README.md` | 設計室自己的 README（與產線不同） |
| `LICENSE` | 各自維護 |
| `github-review-report.md` | Review 記錄 |
| `nix-matrix-review.md` | Nix 審查筆記 |
| `.github/` | 各自的 CI/Actions |
| `.idx/`, `.vscode/` | IDE 設定 |

### 產線專屬（不存在於設計室）

| 檔案 | 說明 |
|------|------|
| `idx-template.json` | IDX 前端參數定義（下拉選單） |
| `idx-template.nix` | 組裝邏輯（template-files/ + envs/ → workspace） |
| `index.html` | 漂亮的按鈕產生器網頁 |
| `README.md` | 產線自己的 README（含 Open in IDX 按鈕） |

---

## 三、正確的編輯位置規則

> **核心原則：改了設計室，就要同步到產線。但改產線專屬檔案，不需要回推。**

| 我要改… | 在哪裡改？ | 然後？ |
|---------|----------|-------|
| nix 環境配置（dev-*.nix） | 設計室 `envs/` | → 同步到產線 `envs/` |
| CLAUDE.md | 設計室 `/CLAUDE.md` | → 複製到產線 `template-files/CLAUDE.md` |
| install.sh | 設計室 `/install.sh` | → 複製到產線 `template-files/install.sh` |
| 腳本（lobster-skillet.sh 等） | 設計室 `scripts/` | → 複製到產線 `template-files/scripts/` |
| IDX 下拉選單、參數 | 產線 `idx-template.json` | 不需回推 |
| IDX 組裝邏輯 | 產線 `idx-template.nix` | 不需回推 |
| 按鈕產生器網頁 | 產線 `index.html` | 不需回推 |
| 技術文件、分析報告 | 設計室 `docs/` | 不需推到產線 |

---

## 四、同步 SOP

### 觸發條件

每當在**設計室**修改了「需要同步的檔案」（見第二節表格），推送前必須同步到產線。

### 同步指令（在 hp-matrix PowerShell 執行）

```powershell
# ── 設定路徑 ──
$SEED = "c:\Users\ellio\Code\cursor\Playground\openclaw-pain-seed"
$GEN  = "c:\Users\ellio\Code\cursor\Playground\pain-merchant-generator-lite"

# ── 1. 同步 envs/（路徑相同，直接覆蓋） ──
Copy-Item "$SEED\envs\dev-lobster.nix" "$GEN\envs\dev-lobster.nix" -Force
Copy-Item "$SEED\envs\dev-sapper.nix"  "$GEN\envs\dev-sapper.nix"  -Force
Copy-Item "$SEED\envs\dev-fresh.nix"   "$GEN\envs\dev-fresh.nix"   -Force

# ── 2. 同步 template-files/（路徑轉換） ──
Copy-Item "$SEED\CLAUDE.md"                        "$GEN\template-files\CLAUDE.md"                        -Force
Copy-Item "$SEED\install.sh"                       "$GEN\template-files\install.sh"                       -Force
Copy-Item "$SEED\PAIN-000_原型機圖紙.md"           "$GEN\template-files\PAIN-000_原型機圖紙.md"           -Force
Copy-Item "$SEED\docker-compose.yml"               "$GEN\template-files\docker-compose.yml"               -Force
Copy-Item "$SEED\matrix-creator.js"                "$GEN\template-files\matrix-creator.js"                -Force
Copy-Item "$SEED\matrix-gateway.js"                "$GEN\template-files\matrix-gateway.js"                -Force
Copy-Item "$SEED\package.json"                     "$GEN\template-files\package.json"                     -Force
Copy-Item "$SEED\RUNBOOK_PROXYCHAINS_TAILSCALE.md" "$GEN\template-files\RUNBOOK_PROXYCHAINS_TAILSCALE.md" -Force
Copy-Item "$SEED\.gitignore"                       "$GEN\template-files\.gitignore"                       -Force

# ── 3. 同步 scripts/（整個目錄） ──
if (Test-Path "$SEED\scripts") {
    New-Item -ItemType Directory -Force -Path "$GEN\template-files\scripts" | Out-Null
    Copy-Item "$SEED\scripts\*" "$GEN\template-files\scripts\" -Force -Recurse
}

Write-Host "✅ 同步完成。請到 $GEN 執行 git diff 確認後再 commit + push。"
```

### 推送流程

```powershell
# ── 4. 設計室推送 ──
cd $SEED
git add -A
git commit -m "feat/fix: <描述>"
git push ark main

# ── 5. 產線推送（附帶同步聲明） ──
cd $GEN
git add -A
git commit -m "sync: 同步自設計室 <commit hash> — <描述>"
git push origin main
```

---

## 五、版本控制規則

| 項目 | 規則 |
|------|------|
| **版本號** | 設計室 README 和產線 README 使用同一個版本號（如 v4.4） |
| **Tag** | 只在設計室打 tag（因為設計決策在這裡做） |
| **Commit Message** | 設計室用 `feat:`/`fix:` 前綴；產線用 `sync:` 前綴標明來源 |
| **分支** | 兩邊都用 `main` |

---

## 六、給下一個 Antigravity 的話

> 🦐 **嘿，未來的 Antigravity —**
>
> 這兩個 repo 不是連動的，改了一邊不會自動跑到另一邊。記住：
>
> 1. **設計室**（openclaw-pain-seed）是你改 nix、CLAUDE.md、install.sh 的地方
> 2. **產線**（pain-merchant-generator-lite）是 IDX 使用者實際 import 的地方
> 3. 改完設計室 → 跑第四節的同步指令 → 推兩邊
> 4. 如果只改產線專屬的東西（idx-template.json、index.html），不需要回推設計室
> 5. `docs/` 和 `.agents/` 只存在設計室，不進產線
>
> 不確定該改哪邊？查第三節的表格。🦐

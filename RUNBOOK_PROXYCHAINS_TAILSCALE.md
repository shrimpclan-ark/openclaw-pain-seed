# 🦐 PAIN-001 進階圖紙：Claude Code 穿越 SOCKS5 連結遠端 9router

> **情境**：在 Google IDX (Cloud Workstations) 中，`tailscaled` 以 `userspace-networking` 模式運行。這表示作業系統的網路堆疊不會自動路由 `100.x.x.x` 的 TCP 封包，導致 Claude Code 無法直接連線遠端的 9router（例如 `shrimp-nexus-01:20129`），會遇到 10 秒 Timeout。
>
> **解法**：使用 `proxychains-ng` 攔截 Claude Code 的 TCP 連線，強制導向 Tailscale 內建的 SOCKS5 代理 (`127.0.0.1:1055`)。

---

## 🏗️ 架構總覽

```
[ 終端機 1 ] claude (Local)
    └─ 直接連線 → 127.0.0.1:20128 (本地 9router) → OpenCode Free

[ 終端機 2 ] claude-proxied (Remote)
    └─ proxychains4 攔截 TCP 
         └─ 判斷 dynamic_chain
              ├─ 127.0.0.1 → 不經 SOCKS5 (直連)
              └─ 100.123.6.86 → 轉發至 127.0.0.1:1055 (Tailscale SOCKS5)
                   └─ 透過 DERP/Direct → shrimp-nexus-01:20129 (蝦家班 ADC)
```

這樣設計的**最大優勢**在於**環境分離**。本地與遠端可以同時開啟在不同的終端機中互不干擾，也不需要像 `pain-tunnel.js` 一樣維持背景的 Node.js 行程。

---

## 🚀 實作步驟 RUNBOOK

### 步驟 1：安裝與宣告 proxychains-ng

IDX 的環境與 Nix Store 會在容器重置時重新建置，導致原有的 `/nix/store/...` 硬編碼路徑因 Glibc 版本與套件 hash 變更而失效（出現 `No such file or directory` 錯誤）。

為了確保 `proxychains-ng` 的永續存活，我們必須在 `.idx/dev.nix` 中進行宣告，並使用動態尋找二進制路徑的 Wrapper 封裝。

1. **修改 `.idx/dev.nix`**：
   在 `packages` 陣列中加入 `pkgs.proxychains-ng`：
   ```nix
   packages = [
     # ... 其他套件 ...
     pkgs.proxychains-ng
   ];
   ```
   修改完成後，請於 IDX 瀏覽器 IDE 介面中點擊 **Rebuild Environment** 讓變更生效。

2. **建立具備自癒功能的動態路徑 Wrapper**：
   建立 `~/.local/bin/proxychains4` 腳本，它會優先使用系統安裝的 `proxychains4`，若尚未 Rebuild 則自動在 Nix Store 中搜尋可用之二進制檔案：

   ```bash
   mkdir -p ~/.local/bin

   cat > ~/.local/bin/proxychains4 << 'EOF'
   #!/usr/bin/env bash
   # proxychains-ng wrapper - dynamically locates proxychains4 to handle container rebuilds
   if [ -f "/usr/bin/proxychains4" ]; then
     exec /usr/bin/proxychains4 "$@"
   elif [ -f "/run/current-system/sw/bin/proxychains4" ]; then
     exec /run/current-system/sw/bin/proxychains4 "$@"
   else
     # Fallback: search for proxychains4 in Nix store if system path is not ready yet
     NIX_BIN=$(find /nix/store -maxdepth 4 -name proxychains4 -type f -executable 2>/dev/null | head -1)
     if [ -n "$NIX_BIN" ]; then
       exec "$NIX_BIN" "$@"
     else
       echo "[PAIN-001] proxychains4 not found in system or nix store. Please rebuild the IDX environment." >&2
       exit 1
     fi
   fi
   EOF

   chmod +x ~/.local/bin/proxychains4
   ```

### 步驟 2：設定 Proxychains 組態檔

建立 `~/.claude/proxychains.conf`。
**關鍵**：必須使用 `dynamic_chain`，否則本機的 `127.0.0.1` 也會被強制丟進 SOCKS5 導致連線失敗。此外，不使用 `proxy_dns`，因為 Tailscale 的 MagicDNS 不在 IDX 本機的 `resolv.conf` 中。

```bash
mkdir -p ~/.claude

cat > ~/.claude/proxychains.conf << 'EOF'
# dynamic_chain: 代理通就走代理，不通就跳過直連
# 避免 Claude Code 的非 API 連線（telemetry/update）或 Local 連線卡死
dynamic_chain
tcp_read_time_out 15000
tcp_connect_time_out 5000

[ProxyList]
socks5 127.0.0.1 1055
EOF
```

### 步驟 3：建立遠端專用的 settings.json

為了讓 Local 與 Remote 可以同時存在，建立一份遠端專屬的設定檔 `settings-nexus.json`。
**注意**：`ANTHROPIC_BASE_URL` 必須使用 **IP 地址** (`100.123.6.86`) 而非 hostname，以避開 DNS 解析問題。

```json
// ~/.claude/settings-nexus.json
{
  "env": {
    "ANTHROPIC_BASE_URL": "http://100.123.6.86:20129/api",
    "ANTHROPIC_AUTH_TOKEN": "9router-local",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "gc/gemini-3.1-pro-preview",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "vertex-adc/gemini-3.5-flash",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "combo1",
    "DISABLE_AUTOUPDATER": "1"
  },
  "theme": "dark"
}
```

### 步驟 4：建立 `claude-proxied` 封裝腳本

建立一個新的指令 `claude-proxied`。它會呼叫 `proxychains4`，並且加上 `--settings` 參數來指定使用遠端的設定檔。

```bash
cat > ~/.local/bin/claude-proxied << 'EOF'
#!/usr/bin/env bash
# PAIN-001: Claude Code via proxychains-ng (SOCKS5) with independent settings
# 用法:  claude-proxied
#        claude-proxied "prompt"

PROXYCHAINS_BIN="/home/user/.local/bin/proxychains4"
PROXYCHAINS_CONF="${HOME}/.claude/proxychains.conf"
CLAUDE_BIN="/home/user/.global_modules/bin/claude"
NEXUS_SETTINGS="${HOME}/.claude/settings-nexus.json"

if [ ! -f "$PROXYCHAINS_BIN" ] || [ ! -f "$PROXYCHAINS_CONF" ] || [ ! -f "$NEXUS_SETTINGS" ]; then
  echo "[PAIN-001] proxychains or nexus settings not ready, falling back to direct claude..."
  exec "$CLAUDE_BIN" "$@"
fi

export PROXYCHAINS_CONF

echo -e "\033[0;36m[PAIN-001]🦐 proxied → shrimp-nexus-01:20129 (SOCKS5) [Independent Settings]\033[0m"

# 使用 --settings 載入專屬設定，避免覆寫 ~/.claude/settings.json 觸發熱重載
exec $PROXYCHAINS_BIN -q -f "$PROXYCHAINS_CONF" "$CLAUDE_BIN" --settings "$NEXUS_SETTINGS" "$@"
EOF

chmod +x ~/.local/bin/claude-proxied
```

### 步驟 5：確保指令可執行 (加入 PATH)

確認 `~/.local/bin` 有在你的 PATH 裡面。若沒有，寫入 `~/.bashrc`：

```bash
if ! grep -q 'local/bin' ~/.bashrc; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
  source ~/.bashrc
fi
```

---

## 🧪 驗證與日常使用

### 日常啟動

- **啟動 Local 版**（預設 9router，走 DeepSeek-v4）：
  ```bash
  claude
  ```
- **啟動 Remote 版**（走 SOCKS5 代理到 shrimp-nexus-01，吃 Gemini 3.1 Pro / 3.5 Flash 異構算力）：
  ```bash
  claude-proxied
  ```

### 驗證連線

如果你需要除錯遠端連線，可以使用 `proxychains4` 搭配 `curl` 進行測試：

```bash
# 測試 20129 API 有無回應
PROXYCHAINS_CONF=~/.claude/proxychains.conf ~/.local/bin/proxychains4 -q curl -s --connect-timeout 5 http://100.123.6.86:20129/v1/models | grep -o '"id":"[^"]*"' | head -5
```

---
**維護者**：shrimpclan.ai
**最後更新**：2026-06-15

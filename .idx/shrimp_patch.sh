# 🍤 蝦家班始祖修補腳本：環境變數與 Docker 自癒基因
# =======================================================

# 1. 物理路徑修正：解決 IDX Rootless Docker Socket 斷層
if [ -z "$DOCKER_HOST" ] || [ ! -S "${DOCKER_HOST#unix://}" ]; then
    # 優先檢查常見的 IDX /tmp 路徑
    REAL_SOCK=$(find /tmp -name "docker.sock" -user $(whoami) 2>/dev/null | head -n 1)
    if [ -n "$REAL_SOCK" ]; then
        export DOCKER_HOST="unix://$REAL_SOCK"
    fi
fi

# 2. 進程環境偷渡：恢復被 SSH 閹割的 PATH 與 WORKSPACE_SLUG
CODE_PID=$(ls -d /proc/[0-9]* 2>/dev/null | xargs -I {} grep -aoE "code-oss|node" {}/cmdline 2>/dev/null | head -n 1 | cut -d/ -f3)
if [ -n "$CODE_PID" ] && [ -e "/proc/$CODE_PID/environ" ]; then
    EXTRACTED_SLUG=$(tr '\0' '\n' < "/proc/$CODE_PID/environ" | grep '^WORKSPACE_SLUG=' | cut -d= -f2-)
    if [ -n "$EXTRACTED_SLUG" ]; then
        export WORKSPACE_SLUG="$EXTRACTED_SLUG"
    fi
    EXTRACTED_PATH=$(tr '\0' '\n' < "/proc/$CODE_PID/environ" | grep '^PATH=' | cut -d= -f2- | sed "s|~|$HOME|g")
    if [ -n "$EXTRACTED_PATH" ]; then
        export PATH="$EXTRACTED_PATH:$PATH"
    fi
fi

# 3. 身分定錨：恢復蝦家班威嚴提示字元
export PS1="\[\e[32m\][🍤 蝦家班-${WORKSPACE_SLUG:-PAIN}]\[\e[m\]:\[\e[34m\]\w\[\e[m\]\$ "

# 4. 算力套利預裝：Claude Code 預設指向 9router
if [ ! -f ~/.claude/settings.json ]; then
    mkdir -p ~/.claude
    cat > ~/.claude/settings.json <<EOF
{
  "env": {
    "ANTHROPIC_BASE_URL": "http://127.0.0.1:20128/v1",
    "ANTHROPIC_AUTH_TOKEN": "sk-9router-free-access",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "oc/mimo-v2.5-free",
    "DISABLE_AUTOUPDATER": "1"
  }
}
EOF
fi

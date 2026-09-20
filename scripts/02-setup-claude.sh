#!/usr/bin/env bash
# ============================================================================
#  02-setup-claude.sh  (v3 - 无 GitHub 依赖版)
#  在 WSL2 Ubuntu 内：安装 Node.js → 安装 Claude Code CLI → 接入 DeepSeek API
#
#  用法（在 Ubuntu 终端里执行）：
#     DEEPSEEK_API_KEY='sk-xxxxxxxx' bash 02-setup-claude.sh
#
#  本版特点：Node 从 npmmirror 国内镜像下载，npm 走 npmmirror registry，
#  全程不访问 github.com / raw.githubusercontent.com，无代理也能跑通。
#  脚本幂等：重复运行会覆盖配置，但不会破坏已有安装。
# ============================================================================

set -euo pipefail

# API Key 需自行提供（不要提交真实 Key 到代码仓库）
KEY="${DEEPSEEK_API_KEY:-${1:-}}"
if [[ -z "$KEY" ]]; then
  echo "错误：未提供 DeepSeek API Key。"
  echo "用法： DEEPSEEK_API_KEY='sk-xxxxxx' bash $0"
  exit 1
fi

SUDO=""
[[ "$(id -u)" -ne 0 ]] && SUDO="sudo"

step() { printf '\n\033[36m==== %s ====\033[0m\n' "$1"; }
ok()   { printf '  \033[32m[OK]\033[0m %s\n' "$1"; }
warn() { printf '  \033[33m[!!]\033[0m %s\n' "$1"; }

# ------------------------------------------------------------------ 0. 依赖
step "0/6 安装基础依赖（需要 sudo 密码）"
$SUDO apt-get update -y
$SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y \
      curl git ca-certificates jq xz-utils
ok "基础依赖就绪"

# --------------------------------------------------------------- 1. Node.js
step "1/6 安装 Node.js（npmmirror 国内镜像，直连可用）"
NODE_HOME="$HOME/.local/node"
if [[ -x "$NODE_HOME/bin/node" ]]; then
  ok "Node 已存在（$($NODE_HOME/bin/node -v)），跳过下载"
else
  echo "  获取最新 Node v22 版本号 ..."
  VER=$(curl -fsSL https://cdn.npmmirror.com/binaries/node/index.json \
        | jq -r '[.[] | select(.version | startswith("v22."))][0].version')
  [[ -n "$VER" && "$VER" != "null" ]] || VER="v22.14.0"
  URL="https://cdn.npmmirror.com/binaries/node/${VER}/node-${VER}-linux-x64.tar.xz"
  echo "  下载 $URL ..."
  curl -fL --retry 3 -o /tmp/node.tar.xz "$URL"
  mkdir -p "$NODE_HOME"
  tar -xJf /tmp/node.tar.xz -C "$NODE_HOME" --strip-components=1
  rm -f /tmp/node.tar.xz
  ok "解压到 $NODE_HOME"
fi
export PATH="$NODE_HOME/bin:$PATH"
# 写入 .bashrc（幂等）
if ! grep -q '\.local/node/bin' "$HOME/.bashrc" 2>/dev/null; then
  printf '\nexport PATH="$HOME/.local/node/bin:$PATH"\n' >> "$HOME/.bashrc"
  ok "已写入 ~/.bashrc（PATH）"
fi
ok "Node $(node -v) / npm $(npm -v)"

# ------------------------------------------------------------- 2. npm 镜像
step "2/6 配置 npm 国内镜像"
npm config set registry https://registry.npmmirror.com
npm config set fetch-timeout 600000
ok "registry = $(npm config get registry)"

# ------------------------------------------------------- 3. Claude Code CLI
step "3/6 安装 Claude Code CLI"
npm install -g @anthropic-ai/claude-code
hash -r
ok "claude 版本：$(claude --version 2>&1 | head -1)"

# --------------------------------------------------- 4. 写入 DeepSeek 配置
step "4/6 写入 DeepSeek 配置 ~/.claude/settings.json"
mkdir -p "$HOME/.claude"
cat > "$HOME/.claude/settings.json" <<JSON
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://api.deepseek.com/anthropic",
    "ANTHROPIC_AUTH_TOKEN": "$KEY",
    "ANTHROPIC_MODEL": "deepseek-v4-pro[1m]",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "deepseek-v4-pro[1m]",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "deepseek-v4-pro[1m]",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "deepseek-v4-flash[1m]",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1",
    "CLAUDE_CODE_EFFORT_LEVEL": "max"
  }
}
JSON
chmod 600 "$HOME/.claude/settings.json"
ok "已写入 $HOME/.claude/settings.json（权限 600）"

# -------------------------------------------------------- 5. 跳过首次引导
step "5/6 预置 onboarding，避免首次运行弹交互向导"
if [[ ! -f "$HOME/.claude.json" ]]; then
  printf '{\n  "hasCompletedOnboarding": true\n}\n' > "$HOME/.claude.json"
  ok "已创建 $HOME/.claude.json"
else
  ok "$HOME/.claude.json 已存在，未覆盖"
fi

# ------------------------------------------------------ 6. 网络连通性验证
step "6/6 验证：查询 DeepSeek 可用模型列表"
echo "  请求 GET https://api.deepseek.com/models ..."
MODELS=$(curl -sS -m 30 https://api.deepseek.com/models -H "Authorization: Bearer $KEY" || echo "")
if [[ -z "$MODELS" ]]; then
  warn "未取到模型列表，请检查网络或 API Key 是否有效"
else
  echo "$MODELS" | jq -r '.data[].id' 2>/dev/null | sed 's/^/    - /' || echo "$MODELS"
fi

echo ""
echo "============================================================================"
echo " 安装完成。验证命令："
echo "   node -v                    # 应输出 v22.x（>= 18 即可）"
echo "   claude --version           # 应输出 Claude Code 版本号"
echo "   cat ~/.claude/settings.json"
echo ""
echo " 端到端连通性测试："
echo "   claude -p '只回复两个字：可用' --output-format text"
echo "============================================================================"

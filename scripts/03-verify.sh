#!/usr/bin/env bash
# ============================================================================
#  03-verify.sh —— 在 WSL2 Ubuntu 内逐项验证 Claude Code + DeepSeek 配置
#  用法： bash 03-verify.sh
# ============================================================================

PASS=0; FAIL=0
chk() { # chk "描述" "命令" [期望正则]
  local desc="$1" cmd="$2" exp="${3:-}" out rc
  out=$(eval "$cmd" 2>&1); rc=$?
  if [[ $rc -eq 0 && ( -z "$exp" || "$out" =~ $exp ) ]]; then
    printf '  \033[32m[PASS]\033[0m %-34s %s\n' "$desc" "$(echo "$out" | head -1)"
    PASS=$((PASS+1))
  else
    printf '  \033[31m[FAIL]\033[0m %-34s %s\n' "$desc" "$(echo "$out" | head -1)"
    FAIL=$((FAIL+1))
  fi
}

echo "==== A. 运行时版本 ===="
chk "Node.js >= 18"      "node -v"               '^v(1[89]|[2-9][0-9])\.'
chk "npm 可用"           "npm -v"                '^[0-9]+\.'
chk "Claude Code CLI"    "claude --version"      '^[0-9]+\.'

echo ""
echo "==== B. DeepSeek 配置 ===="
chk "settings.json 存在" "test -f \$HOME/.claude/settings.json"
chk "BASE_URL 正确"      "jq -r '.env.ANTHROPIC_BASE_URL' \$HOME/.claude/settings.json" '^https://api\.deepseek\.com/anthropic$'
chk "已填入 API Key"     "jq -r '.env.ANTHROPIC_AUTH_TOKEN' \$HOME/.claude/settings.json" '^sk-.+'
chk "JSON 格式合法"      "jq -e . \$HOME/.claude/settings.json >/dev/null"

echo ""
echo "==== C. 网络连通性 ===="
KEY=$(jq -r '.env.ANTHROPIC_AUTH_TOKEN' "$HOME/.claude/settings.json" 2>/dev/null || echo "")
if [[ -n "$KEY" && "$KEY" != "null" ]]; then
  chk "api.deepseek.com 可达" "curl -sS -m 20 -o /dev/null -w '%{http_code}' https://api.deepseek.com/models -H 'Authorization: Bearer $KEY'" '^200$'
  echo "  可用模型 ID："
  curl -sS -m 20 https://api.deepseek.com/models -H "Authorization: Bearer $KEY" \
    | jq -r '.data[].id' 2>/dev/null | sed 's/^/    - /' || echo "    (解析失败)"
else
  echo "  [SKIP] 未读到 API Key"
fi

echo ""
echo "==== D. 端到端（真实调用模型，约需 10-60 秒）===="
echo "  执行：claude -p '只回复两个字：可用' --output-format text"
if timeout 180 claude -p "只回复两个字：可用" --output-format text 2>&1 | tail -5; then
  echo "  [PASS] 端到端调用成功（上方出现了模型回复）"
  PASS=$((PASS+1))
else
  echo "  [FAIL] 端到端调用失败 —— 检查 Key 余额 / 模型名 / 网络"
  FAIL=$((FAIL+1))
fi

echo ""
echo "=========================================="
echo "  通过 $PASS 项，失败 $FAIL 项"
echo "=========================================="
[[ $FAIL -eq 0 ]]

# ============================================================================
#  04-verify.ps1
#  One-shot verification of WSL2 from the Windows side.
#  Run in a NORMAL PowerShell (no admin needed):
#     & "$HOME\WorkBuddy\2026-09-20-10-03-15\wsl-claude-setup\04-verify.ps1"
#
#  ASCII-only on purpose: PowerShell 5.1 reads .ps1 as ANSI (GBK) without a
#  UTF-8 BOM, and mojibake can break parsing. Keep this file ASCII-only.
# ============================================================================

Write-Host "==== 1. Distro list (VERSION column must be 2; Ubuntu row must start with '*') ====" -ForegroundColor Cyan
wsl -l -v

Write-Host ""
Write-Host "==== 2. WSL overall status ====" -ForegroundColor Cyan
wsl --status

Write-Host ""
Write-Host "==== 3. Probe inside WSL ====" -ForegroundColor Cyan
wsl -- bash -lc '
  echo "kernel     : $(uname -r)"
  echo "distro     : $(. /etc/os-release && echo "$PRETTY_NAME")"
  echo -n "Node.js    : "; node -v 2>/dev/null || echo "not installed"
  echo -n "npm        : "; npm -v 2>/dev/null || echo "not installed"
  echo -n "Claude CLI : "; claude --version 2>/dev/null || echo "not installed"
  echo -n "settings   : "; test -f "$HOME/.claude/settings.json" && echo "present" || echo "MISSING"
  if [ -f "$HOME/.claude/settings.json" ]; then
    echo "BASE_URL   : $(jq -r ".env.ANTHROPIC_BASE_URL" "$HOME/.claude/settings.json")"
    echo "main model : $(jq -r ".env.ANTHROPIC_MODEL" "$HOME/.claude/settings.json")"
  fi
'

Write-Host ""
Write-Host "NOTE: VERSION must be 2. If it shows 1, run:  wsl --set-version Ubuntu 2" -ForegroundColor Yellow

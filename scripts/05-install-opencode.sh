#!/usr/bin/env bash
# scripts/05-install-opencode.sh
# Route B: install OpenCode CLI inside WSL Ubuntu and configure OpenCode Go.
#
# Usage:
#   bash scripts/05-install-opencode.sh
#   OPENCODE_GO_API_KEY='sk-go-xxxx' bash scripts/05-install-opencode.sh
#
# Notes:
#   - Everything comes from npmmirror, no GitHub / proxy needed.
#   - The key is written to ~/.local/share/opencode/auth.json (chmod 600).
#   - The key is never echoed back in full.

set -euo pipefail

NPM_BIN_DIR="${HOME}/.local/node/bin"
export PATH="${NPM_BIN_DIR}:${PATH}"
REGISTRY="https://registry.npmmirror.com"
AUTH_FILE="${HOME}/.local/share/opencode/auth.json"

info() { printf '[INFO] %s\n' "$*"; }
ok()   { printf '[ OK ] %s\n' "$*"; }
err()  { printf '[FAIL] %s\n' "$*" >&2; }

# ---------------------------------------------------------------- 1. Node.js
if ! command -v node >/dev/null 2>&1; then
  err "Node.js not found. Run scripts/02-setup-claude.sh first (it installs Node 22 LTS)."
  exit 1
fi
ok "Node.js $(node -v) / npm $(npm -v)"

# ------------------------------------------------------- 2. install opencode
info "Installing opencode-ai from ${REGISTRY} ..."
npm install -g opencode-ai --registry="${REGISTRY}"

if ! command -v opencode >/dev/null 2>&1; then
  export PATH="${NPM_BIN_DIR}:${PATH}"
fi
if ! command -v opencode >/dev/null 2>&1; then
  err "'opencode' still not on PATH."
  err "Fix permanently with:"
  err "  echo 'export PATH=\"\$HOME/.local/node/bin:\$PATH\"' >> ~/.bashrc && source ~/.bashrc"
  exit 1
fi
ok "opencode installed: $(command -v opencode)"

# ------------------------------------------------------------ 3. credentials
KEY="${OPENCODE_GO_API_KEY:-}"

if [ -z "${KEY}" ]; then
  info "No OPENCODE_GO_API_KEY given, asking interactively."
  info "Paste your OpenCode Go key (starts with sk-go-), then press Enter."
  read -r -p "Key: " KEY
fi

if [ -z "${KEY}" ]; then
  err "Empty key, skipping auth.json. You can set it later in the TUI (/connect)"
  err "or by writing ${AUTH_FILE} manually."
  exit 0
fi

mkdir -p "$(dirname "${AUTH_FILE}")"
printf '{"opencode-go":{"type":"api","key":"%s"}}\n' "${KEY}" > "${AUTH_FILE}"
chmod 600 "${AUTH_FILE}"
ok "Wrote ${AUTH_FILE} (permission 600)"
info "Key preview: ${KEY:0:6}...${KEY: -4}"

# ------------------------------------------------------------------ 4. verify
info "Verifying installation ..."
opencode --version || true

cat <<'EOF'

Done. Next steps:

  1. go to your project folder first, then start the TUI:
       cd ~/your-project && opencode

  2. check the status bar at the bottom: it must show "OpenCode Go"
     (means the key is accepted)

  3. pick a model: type /models and press Enter
       - GLM-5.2          -> daily driver (code + research text)
       - Kimi K3          -> long papers / long PDFs
       - DeepSeek V4 Flash-> cheap batch jobs
       - Qwen3.8 Max      -> writing and polishing

  4. switch model any time: /models  (or Ctrl+P -> models)

Paste in the TUI: right-click is blocked, use Ctrl+Shift+V or Shift+Insert.
EOF

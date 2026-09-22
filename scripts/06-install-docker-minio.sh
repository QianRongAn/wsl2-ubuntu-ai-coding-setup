#!/usr/bin/env bash
# scripts/06-install-docker-minio.sh
#
# Optional add-on: install Docker Engine (docker-ce via Aliyun mirror) and run a
# MinIO object-storage container inside WSL2 Ubuntu.
#
# Idempotent: skips what is already done. Safe to re-run.
#
# Usage:
#   bash scripts/06-install-docker-minio.sh
#   MINIO_ROOT_USER=admin MINIO_ROOT_PASSWORD=secret123 bash scripts/06-install-docker-minio.sh

set -euo pipefail

DOCKER_MIRROR="https://mirrors.aliyun.com/docker-ce/linux/ubuntu"
MINIO_ROOT_USER="${MINIO_ROOT_USER:-minioadmin}"
MINIO_ROOT_PASSWORD="${MINIO_ROOT_PASSWORD:-minioadmin}"

# NOTE (2026-09): MinIO has archived its open-source community edition and pulled
# all binaries from dl.min.io (every path now returns HTTP 410 Gone).
# The image on Docker Hub also can no longer be relied on for pulls; the
# maintained registry is quay.io. Version pinned to the last official community
# release instead of 'latest', so the tag cannot silently change under you.
MINIO_IMAGE="${MINIO_IMAGE:-quay.io/minio/minio:RELEASE.2025-09-07T16-13-09Z}"

info() { printf '[INFO] %s\n' "$*"; }
ok()   { printf '[ OK ] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
err()  { printf '[FAIL] %s\n' "$*" >&2; }

# ------------------------------------------------- 0. systemd (docker needs it)
if ! ps -p 1 -o comm= 2>/dev/null | grep -q systemd; then
  warn "PID 1 is not systemd -- Docker service management will not work."
  if [ ! -f /etc/wsl.conf ] || ! grep -q '^\s*systemd\s*=\s*true' /etc/wsl.conf; then
    info "Enabling systemd in /etc/wsl.conf ..."
    sudo mkdir -p /etc
    if [ -f /etc/wsl.conf ]; then
      sudo cp /etc/wsl.conf "/etc/wsl.conf.bak.$(date +%s)"
    fi
    # append [boot] section, or add systemd=true under an existing [boot]
    if grep -q '^\[boot\]' /etc/wsl.conf 2>/dev/null; then
      sudo sed -i 's/^systemd\s*=.*/systemd=true/' /etc/wsl.conf
      grep -q '^\s*systemd\s*=' /etc/wsl.conf || sudo sed -i '/^\[boot\]/a systemd=true' /etc/wsl.conf
    else
      printf '\n[boot]\nsystemd=true\n' | sudo tee -a /etc/wsl.conf > /dev/null
    fi
  fi
  err "systemd is required for Docker."
  err "Run this on Windows:  wsl --shutdown"
  err "Then re-enter Ubuntu and run this script again."
  exit 1
fi
ok "systemd is PID 1"

# ---------------------------------------------------------------- 1. Docker
if command -v docker >/dev/null 2>&1; then
  ok "docker already installed: $(docker --version)"
else
  info "Installing Docker (docker-ce) via Aliyun mirror ..."
  sudo apt-get update
  sudo apt-get install -y ca-certificates curl gnupg
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL "${DOCKER_MIRROR}/gpg" | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg
  arch="$(dpkg --print-architecture)"
  codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"
  echo "deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.gpg] ${DOCKER_MIRROR} ${codename} stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  ok "docker installed: $(docker --version)"
fi

sudo systemctl enable --now docker >/dev/null 2>&1 || true
sudo usermod -aG docker "$USER" 2>/dev/null || true

# registry mirror (avoids docker hub slowness/blocking)
if [ ! -f /etc/docker/daemon.json ]; then
  info "Adding registry mirror to /etc/docker/daemon.json ..."
  sudo mkdir -p /etc/docker
  printf '{\n  "registry-mirrors": ["https://docker.m.daocloud.io", "https://dockerproxy.com"]\n}\n' \
    | sudo tee /etc/docker/daemon.json > /dev/null
  sudo systemctl restart docker || true
fi

# The group change above only applies to NEW sessions. On the very first run of
# this script the current shell still lacks docker access -- fall back to sudo.
DK="docker"
if ! docker info >/dev/null 2>&1; then
  DK="sudo docker"
  warn "Current shell is not in the 'docker' group yet -- using sudo for now."
  warn "After this script: run 'newgrp docker' (or reopen the terminal) to drop sudo."
fi

# ----------------------------------------------------------------- 2. MinIO
if $DK ps -a --format '{{.Names}}' 2>/dev/null | grep -qx minio; then
  ok "minio container already exists (skipped)"
  $DK ps --format '{{.Names}}\t{{.Status}}' | grep -x 'minio.*' || true
else
  info "Starting MinIO (S3-compatible object storage) ..."
  mkdir -p "$HOME/minio/data"
  $DK run -d --name minio \
    -p 9000:9000 -p 9001:9001 \
    -v "$HOME/minio/data:/data" \
    -e "MINIO_ROOT_USER=${MINIO_ROOT_USER}" \
    -e "MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD}" \
    --restart unless-stopped \
    "$MINIO_IMAGE" server /data --console-address ":9001"
  ok "minio started (image: $MINIO_IMAGE)"
fi

cat <<EOF

Done.

  Docker           : docker --version
                     docker run --rm hello-world     (pulls via mirror)
  MinIO API        : http://localhost:9000
  MinIO console    : http://localhost:9001
                     login = ${MINIO_ROOT_USER} / ${MINIO_ROOT_PASSWORD}
  MinIO data dir   : ~/minio/data

Next steps:
  newgrp docker        # or reopen the terminal, then docker works without sudo
  docker ps            # should list the minio container

Security note: the default password is 'minioadmin'. To change it, remove the
container first, then re-run this script with MINIO_ROOT_PASSWORD set:
  docker rm -f minio && MINIO_ROOT_PASSWORD='<strong-password>' bash $0
EOF

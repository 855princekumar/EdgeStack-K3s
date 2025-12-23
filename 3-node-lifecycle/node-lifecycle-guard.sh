#!/usr/bin/env bash
# node-lifecycle-guard.sh
# Universal node self-healing policy

set -euo pipefail

echo "[node-guard] Installing lifecycle guarantees"

# ---- systemd override for k3s ----
for svc in k3s k3s-agent; do
  if systemctl list-unit-files | grep -q "^${svc}"; then
    mkdir -p /etc/systemd/system/${svc}.service.d
    cat > /etc/systemd/system/${svc}.service.d/override.conf <<EOF
[Service]
Restart=always
RestartSec=5
StartLimitInterval=0
EOF
  fi
done

# ---- kernel panic auto reboot ----
sysctl -w kernel.panic=10
sysctl -w kernel.panic_on_oops=1

# ---- OOM behavior (let kernel kill, not hang) ----
sysctl -w vm.panic_on_oom=0

systemctl daemon-reexec

echo "[node-guard] Node lifecycle protection active"
 
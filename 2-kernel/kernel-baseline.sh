#!/usr/bin/env bash
# kernel-baseline.sh
# Universal Linux kernel baseline for K3s / Kubernetes
# ARM + x86 compatible

set -euo pipefail

echo "[kernel-baseline] Applying kernel & VM defaults"

# ---- cgroups (boot-level, idempotent) ----
CMDLINE="/boot/cmdline.txt"
if [ -f "$CMDLINE" ] && ! grep -q "cgroup_memory=1" "$CMDLINE"; then
  sed -i '1 s/$/ cgroup_memory=1 cgroup_enable=memory/' "$CMDLINE"
  echo "[kernel-baseline] cgroups enabled (reboot required)"
fi

# ---- sysctl tuning ----
SYSCTL="/etc/sysctl.d/99-kernel-baseline.conf"
cat > "$SYSCTL" <<EOF
vm.swappiness=60
vm.overcommit_memory=1
vm.vfs_cache_pressure=50
fs.inotify.max_user_instances=8192
fs.inotify.max_user_watches=1048576
kernel.panic=10
kernel.panic_on_oops=1
EOF

sysctl --system >/dev/null

echo "[kernel-baseline] Done"
echo "⚠️ Reboot once to fully apply kernel flags"
 
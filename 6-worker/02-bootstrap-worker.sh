#!/bin/bash
set -e

MASTER_IP="10.1.40.22"
TOKEN_FILE="/tmp/k3s-token"

echo "🔗 Bootstrapping WORKER $(hostname)"

sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget git

# ---------- ENABLE CGROUPS ----------
CMDLINE="/boot/cmdline.txt"
if ! grep -q "cgroup_memory=1" $CMDLINE; then
  sudo sed -i '1 s/$/ cgroup_memory=1 cgroup_enable=memory/' $CMDLINE
  echo "♻️ Reboot required"
  sudo reboot
fi

# ---------- FETCH TOKEN ----------
scp dcn1@${MASTER_IP}:/opt/k3s-token ${TOKEN_FILE}

# ---------- INSTALL K3s AGENT ----------
curl -sfL https://get.k3s.io | \
K3S_URL="https://${MASTER_IP}:6443" \
K3S_TOKEN="$(cat ${TOKEN_FILE})" \
INSTALL_K3S_VERSION=${K3S_VERSION} \
sh -

echo "✅ WORKER JOINED"
 
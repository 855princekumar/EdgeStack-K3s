#!/bin/bash
set -e

echo "🚀 Bootstrapping K3s MASTER (dcn1)"

# ---------- SYSTEM PREP ----------
sudo apt update && sudo apt full-upgrade -y
sudo apt install -y curl wget git vim net-tools unzip tar

# ---------- ENABLE CGROUPS ----------
CMDLINE="/boot/cmdline.txt"
if ! grep -q "cgroup_memory=1" $CMDLINE; then
  sudo sed -i '1 s/$/ cgroup_memory=1 cgroup_enable=memory/' $CMDLINE
  echo "♻️ Reboot required to enable cgroups"
  sudo reboot
fi

# ---------- INSTALL K3s SERVER ----------
curl -sfL https://get.k3s.io | \
INSTALL_K3S_VERSION=${K3S_VERSION} \
INSTALL_K3S_EXEC="server --node-ip=${MASTER_IP} --tls-san=${MASTER_IP}" \
sh -

# ---------- KUBECTL ACCESS ----------
mkdir -p $HOME/.kube
sudo cp /etc/rancher/k3s/k3s.yaml $HOME/.kube/config
sudo chown $USER:$USER $HOME/.kube/config
export KUBECONFIG=$HOME/.kube/config

# ---------- TOKEN EXPORT ----------
echo "📌 Saving join token"
sudo cat /var/lib/rancher/k3s/server/node-token | sudo tee /opt/k3s-token

echo "✅ MASTER READY"
kubectl get nodes

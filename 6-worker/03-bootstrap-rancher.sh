#!/bin/bash
set -e

echo "🖥️ Bootstrapping Rancher GUI (dcn0)"

# ---------- INSTALL DOCKER ----------
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker

# ---------- ENABLE BOOT ----------
sudo systemctl enable docker
sudo systemctl start docker

# ---------- RUN RANCHER ----------
docker run -d \
  --restart=unless-stopped \
  --name rancher \
  --privileged \
  -p 80:80 -p 443:443 \
  rancher/rancher:${RANCHER_VERSION}

echo "🌐 Rancher UI will be available at:"
echo "👉 https://10.1.40.21"
 
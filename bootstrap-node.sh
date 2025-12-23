#!/usr/bin/env bash
set -euo pipefail

############################################
# Global helpers
############################################
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG="/var/log/bootstrap-node.log"

exec > >(tee -a "$LOG") 2>&1

info() { echo -e "\n[INFO] $1"; }
warn() { echo -e "\n[WARN] $1"; }
die()  { echo -e "\n[ERROR] $1"; exit 1; }

############################################
# Detect system
############################################
ARCH="$(uname -m)"
OS_ID="$(. /etc/os-release && echo "$ID")"

IS_PI=false
IS_X86=false

if [[ "$ARCH" == "armv7l" || "$ARCH" == "aarch64" ]]; then
  if grep -qi raspberry /proc/cpuinfo; then
    IS_PI=true
  fi
elif [[ "$ARCH" == "x86_64" ]]; then
  IS_X86=true
fi

info "Architecture: $ARCH"
info "OS: $OS_ID"
info "Detected Raspberry Pi: $IS_PI"
info "Detected x86: $IS_X86"

############################################
# Role selection
############################################
echo
echo "Select node role:"
select ROLE in "master" "worker" "rancher"; do
  case $ROLE in
    master|worker|rancher) break ;;
    *) echo "Invalid choice";;
  esac
done

info "Selected role: $ROLE"

############################################
# Base layers (ALL nodes)
############################################
run_dir() {
  local dir="$1"
  [[ -d "$dir" ]] || return
  for f in "$dir"/*; do
    [[ -x "$f" ]] || continue
    info "Executing $f"
    "$f"
  done
}

############################################
# 0-networking (optional, interactive)
############################################
read -rp "Configure static IP now? (y/N): " DO_NET
if [[ "${DO_NET,,}" == "y" ]]; then
  run_dir "$ROOT_DIR/0-networking"
else
  warn "Skipping static IP configuration"
fi

############################################
# Mandatory base layers
############################################
run_dir "$ROOT_DIR/1-time-sync"
run_dir "$ROOT_DIR/2-kernel"
run_dir "$ROOT_DIR/3-node-lifecycle"

############################################
# Edge-Pulse (only supported platforms)
############################################
if [[ "$IS_PI" == true ]]; then
  info "Installing Edge-Pulse for Raspberry Pi"
  run_dir "$ROOT_DIR/4-edge-pulse"
else
  warn "Edge-Pulse skipped (unsupported hardware)"
fi

############################################
# Role-specific setup
############################################
case "$ROLE" in
  master)
    run_dir "$ROOT_DIR/5-master"
    ;;
  worker)
    run_dir "$ROOT_DIR/6-worker"
    ;;
  rancher)
    run_dir "$ROOT_DIR/7-rancher"
    ;;
esac

info "Bootstrap completed successfully"
warn "Reboot recommended if kernel or networking changed"

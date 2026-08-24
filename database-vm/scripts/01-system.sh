#!/usr/bin/env bash

# Operating system preparation

set -euo pipefail

log() {
    printf "\n==================================================\n"
    printf "%s\n" "$1"
    printf "==================================================\n"
}

export DEBIAN_FRONTEND=noninteractive

echo "==> Updating package lists..."
apt-get update
apt-get upgrade -y

echo "==> Installing system dependencies..."
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Do not run a full distribution/kernel upgrade here. A kernel upgrade can
# invalidate the VirtualBox or Parallels guest modules used for shared folders.
apt-get autoclean -y

echo "==> System provisioning completed."

#!/usr/bin/env bash

# Developer/admin tools installation

set -euo pipefail

log() {
    printf "\n==================================================\n"
    printf "%s\n" "$1"
    printf "==================================================\n"
}

export DEBIAN_FRONTEND=noninteractive

echo "==> Installing additional tools..."

# Install common tools
apt-get install -y \
    git \
    htop \
    jq \
    nano \
    tree \
    unzip \
    vim \
    wget \
    net-tools

echo "==> Tools provisioning completed."
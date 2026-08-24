#!/usr/bin/env bash

# Docker installation

set -euo pipefail

log() {
    printf "\n==================================================\n"
    printf "%s\n" "$1"
    printf "==================================================\n"
}

export DEBIAN_FRONTEND=noninteractive

echo "==> Installing Docker..."

# Create keyring directory
install -m 0755 -d /etc/apt/keyrings

# Add Docker GPG key (only once)
if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
fi

chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repository (only once)
if [ ! -f /etc/apt/sources.list.d/docker.list ]; then
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    > /etc/apt/sources.list.d/docker.list
fi

apt-get update

# Install Docker packages
apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

# Enable Docker on boot
systemctl enable docker
systemctl start docker

# Allow vagrant user to use Docker
usermod -aG docker vagrant

echo "==> Docker provisioning completed."
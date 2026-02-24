#!/bin/bash
set -euxo pipefail

exec > >(tee /var/log/user-data.log) 2>&1

echo "=== Starting user-data script (race-crew-network) ==="

# Update system packages
dnf update -y

# Install Docker and git
dnf install -y docker git
systemctl enable docker
systemctl start docker
usermod -aG docker ec2-user

# Install Docker Buildx and Compose plugins
mkdir -p /usr/local/lib/docker/cli-plugins

BUILDX_VERSION=0.21.1
ARCH=linux-amd64
curl -SL "https://github.com/docker/buildx/releases/download/v$BUILDX_VERSION/buildx-v$BUILDX_VERSION.$ARCH" \
  -o /usr/local/lib/docker/cli-plugins/docker-buildx
chmod +x /usr/local/lib/docker/cli-plugins/docker-buildx

curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-Linux-x86_64" \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# Clone the repository
cd /home/ec2-user
git clone ${repo_url} app
chown -R ec2-user:ec2-user app

echo "=== user-data script complete ==="
docker --version
docker compose version

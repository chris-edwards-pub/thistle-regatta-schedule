#!/bin/bash
set -euxo pipefail

exec > >(tee /var/log/user-data.log) 2>&1

echo "=== Starting user-data script ==="

# Update system packages
dnf update -y

# Install Docker and git
dnf install -y docker git
systemctl enable docker
systemctl start docker
usermod -aG docker ec2-user

# Install Docker Compose plugin
mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# Clone the repository
cd /home/ec2-user
git clone ${repo_url} app
chown -R ec2-user:ec2-user app

echo "=== user-data script complete ==="
echo "Docker version: $(docker --version)"
echo "Docker Compose version: $(docker compose version)"

#!/bin/bash

# Update system packages
apt-get update -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker ubuntu

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/download/v2.21.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install Python and pip for Ansible
apt-get install -y python3 python3-pip

# Install Google Cloud SDK
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# Create directories for monitoring configs
mkdir -p /opt/monitoring/{prometheus,loki,grafana,promtail,otel}
chown -R ubuntu:ubuntu /opt/monitoring

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Enable and start Docker service
systemctl enable docker
systemctl start docker

# Create monitoring user
useradd -m -s /bin/bash monitoring
usermod -aG docker monitoring

echo "VM startup script completed successfully" | tee /var/log/startup-script.log
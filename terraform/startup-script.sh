#!/bin/bash

# Update system
apt-get update -y
apt-get upgrade -y

# Install required packages
apt-get install -y curl wget gnupg2 software-properties-common apt-transport-https ca-certificates

# Install Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Add ubuntu user to docker group
usermod -aG docker ubuntu

# Install Python and pip
apt-get install -y python3 python3-pip

# Install Ansible
pip3 install ansible

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install Helm
curl https://baltocdn.com/helm/signing.asc | apt-key add -
echo "deb https://baltocdn.com/helm/stable/debian/ all main" | tee /etc/apt/sources.list.d/helm-stable-debian.list
apt-get update -y
apt-get install -y helm

# Install Google Cloud SDK
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
apt-get update -y
apt-get install -y google-cloud-sdk

# Create monitoring directories
mkdir -p /opt/monitoring
mkdir -p /opt/monitoring/configs
mkdir -p /opt/monitoring/data

# Set permissions
chown -R ubuntu:ubuntu /opt/monitoring

# Enable and start Docker
systemctl enable docker
systemctl start docker

# Create a systemd service for monitoring stack
cat > /etc/systemd/system/monitoring-stack.service << 'EOF'
[Unit]
Description=Monitoring Stack
After=docker.service
Requires=docker.service

[Service]
Type=forking
User=ubuntu
Group=ubuntu
WorkingDirectory=/opt/monitoring
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable monitoring-stack

echo "Startup script completed" > /var/log/startup-script.log
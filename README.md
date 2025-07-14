# GCP Monitoring Infrastructure

This repository contains Terraform and Ansible configurations to deploy a comprehensive monitoring stack on Google Cloud Platform (GCP) for monitoring GKE clusters and pods.

## Architecture

The monitoring stack includes:
- **Prometheus**: Metrics collection and alerting
- **Grafana**: Visualization dashboard
- **Loki**: Log aggregation 
- **Promtail**: Log collection
- **OpenTelemetry**: Distributed tracing
- **Jaeger**: Trace visualization
- **AlertManager**: Alert routing and management
- **Node Exporter**: Host metrics
- **cAdvisor**: Container metrics

## Prerequisites

1. **GCP Account**: Access to `rizzup-dev` project
2. **Tools Installation**:
   ```bash
   # Install gcloud CLI
   curl https://sdk.cloud.google.com | bash
   
   # Install Terraform
   wget https://releases.hashicorp.com/terraform/1.5.0/terraform_1.5.0_linux_amd64.zip
   unzip terraform_1.5.0_linux_amd64.zip
   sudo mv terraform /usr/local/bin/
   
   # Install Ansible
   pip install ansible
   ansible-galaxy collection install community.docker
   ```

3. **SSH Key**: Generate SSH key pair
   ```bash
   ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
   ```

## Quick Start

1. **Clone the repository**:
   ```bash
   git clone https://github.com/midnightcrisis/semaphores.git
   cd semaphores
   ```

2. **Authenticate with GCP**:
   ```bash
   gcloud auth login
   gcloud config set project rizzup-dev
   ```

3. **Deploy the infrastructure**:
   ```bash
   ./deploy.sh
   ```

This will:
- Create a GCP VM with networking and firewall rules
- Install Docker and monitoring stack
- Configure all monitoring services
- Provide access URLs

## Manual Deployment

### Step 1: Deploy Infrastructure with Terraform

```bash
cd terraform
terraform init
terraform plan -var="project_id=rizzup-dev"
terraform apply -var="project_id=rizzup-dev"
```

### Step 2: Configure Monitoring with Ansible

```bash
# Update inventory with VM IP
VM_IP=$(cd terraform && terraform output -raw vm_external_ip)
sed -i "s/MONITORING_VM_IP/$VM_IP/g" ansible/inventory/hosts.ini

# Deploy monitoring stack
cd ansible
ansible-playbook -i inventory/hosts.ini playbooks/deploy-monitoring.yml
```

## Configuration

### Terraform Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `project_id` | `rizzup-dev` | GCP Project ID |
| `region` | `us-central1` | GCP Region |
| `zone` | `us-central1-c` | GCP Zone |
| `machine_type` | `e2-standard-4` | VM Instance Type |
| `disk_size` | `50` | Boot disk size in GB |

### Ansible Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `grafana_admin_password` | `admin123` | Grafana admin password |
| `gcp_project_id` | `rizzup-dev` | GCP Project ID |
| `monitoring_dir` | `/opt/monitoring` | Monitoring configs directory |

## Service Access

After deployment, access the monitoring services:

- **Grafana**: `http://VM_IP:3000`
  - Username: `admin`
  - Password: `admin123`
- **Prometheus**: `http://VM_IP:9090`
- **Loki**: `http://VM_IP:3100`
- **Jaeger**: `http://VM_IP:16686`
- **OpenTelemetry**: `http://VM_IP:4317`
- **AlertManager**: `http://VM_IP:9093`

## GKE Cluster Monitoring

To monitor GKE clusters:

1. **Connect to GKE**:
   ```bash
   gcloud container clusters get-credentials CLUSTER_NAME --zone=ZONE
   ```

2. **Deploy monitoring agents**:
   ```bash
   kubectl apply -f k8s/monitoring-agents.yml
   ```

3. **Configure service discovery** in Prometheus for your cluster endpoints.

## Customization

### Adding Custom Dashboards

1. Place dashboard JSON files in `ansible/configs/grafana/dashboards/`
2. Update `grafana-dashboards.yml` configuration
3. Redeploy with Ansible

### Custom Prometheus Rules

1. Add rules to `ansible/configs/prometheus/rules/`
2. Update `prometheus.yml` configuration
3. Reload Prometheus configuration

### Log Collection

Promtail is configured to collect:
- System logs from `/var/log/*`
- Container logs from Docker
- Kubernetes pod logs (when connected to GKE)

## Troubleshooting

### Common Issues

1. **VM not accessible**: Check firewall rules and SSH key configuration
2. **Services not starting**: Check Docker daemon and container logs
3. **Monitoring not working**: Verify network connectivity and service discovery

### Debug Commands

```bash
# Check service status
docker-compose ps

# View service logs
docker-compose logs SERVICE_NAME

# SSH to VM
ssh -i ~/.ssh/id_rsa ubuntu@VM_IP

# Check Prometheus targets
curl http://VM_IP:9090/api/v1/targets
```

## Security

- VM uses service account with minimal required permissions
- Firewall rules restrict access to monitoring ports
- SSH key-based authentication
- Internal network communication between services

## Cleanup

To destroy the infrastructure:

```bash
cd terraform
terraform destroy -var="project_id=rizzup-dev"
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test the deployment
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

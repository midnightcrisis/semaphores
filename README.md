# GCP Monitoring Infrastructure

This repository contains Infrastructure as Code (IaC) for setting up a comprehensive monitoring stack on Google Cloud Platform (GCP) for monitoring GKE clusters and pods.

## Architecture

The monitoring stack includes:
- **Prometheus** - Metrics collection and storage
- **Grafana** - Visualization and dashboards
- **Loki** - Log aggregation and storage
- **Promtail** - Log collection agent
- **OpenTelemetry Collector** - Distributed tracing and telemetry
- **Jaeger** - Distributed tracing UI

## Components

### Terraform Infrastructure
- **GCP VM** - Monitoring server with required networking and security
- **Service Account** - With necessary IAM permissions
- **Firewall Rules** - For monitoring stack access
- **VPC Network** - Isolated network for monitoring infrastructure

### Ansible Configuration
- **Automated deployment** of the monitoring stack
- **Docker Compose** orchestration
- **Configuration management** for all components

### Kubernetes Manifests
- **Monitoring namespace** setup
- **RBAC** configuration for cluster access
- **Service discovery** configuration
- **Pod and cluster monitoring** setup

## Prerequisites

1. **GCP Project** - Ensure project ID `rizzup-dev` exists and is accessible
2. **Terraform** - Version >= 1.0
3. **Ansible** - For configuration management
4. **kubectl** - For Kubernetes management
5. **GCP CLI** - For authentication and management

## Quick Start

### 1. Deploy GCP Infrastructure

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### 2. Configure Monitoring Stack

```bash
cd ../ansible
# Update inventory/hosts with the VM IP from Terraform output
ansible-playbook -i inventory/hosts playbooks/monitoring.yml
```

### 3. Deploy Kubernetes Components

```bash
cd ../kubernetes
kubectl apply -f manifests/namespace.yaml
kubectl apply -f manifests/
```

## Configuration

### Project Settings
- **Project ID**: `rizzup-dev`
- **Monitoring Namespace**: `monitoring`
- **Default Region**: `us-central1`

### Access URLs
After deployment, the following services will be available:
- **Grafana**: `http://VM_IP:3000` (admin/admin)
- **Prometheus**: `http://VM_IP:9090`
- **Loki**: `http://VM_IP:3100`
- **Jaeger**: `http://VM_IP:16686`

### Kubernetes Services
- **Grafana**: `http://grafana.monitoring.svc.cluster.local:3000`
- **Prometheus**: `http://prometheus.monitoring.svc.cluster.local:9090`
- **Loki**: `http://loki.monitoring.svc.cluster.local:3100`
- **OpenTelemetry Collector**: `http://otel-collector.monitoring.svc.cluster.local:4317`

## Monitoring Features

### Metrics (Prometheus)
- **Node metrics** - CPU, memory, disk, network
- **Container metrics** - cAdvisor integration
- **Kubernetes metrics** - API server, kubelet, pods
- **Application metrics** - Custom metrics via annotations

### Logs (Loki + Promtail)
- **System logs** - `/var/log/*`
- **Container logs** - Docker container logs
- **Kubernetes logs** - Pod and container logs
- **Application logs** - Structured logging support

### Tracing (OpenTelemetry + Jaeger)
- **Distributed tracing** - Request flow across services
- **Performance monitoring** - Latency and errors
- **Service map** - Service dependency visualization
- **Trace correlation** - Logs and metrics correlation

## Security

### Network Security
- **Firewall rules** - Restrict access to monitoring ports
- **VPC isolation** - Dedicated network for monitoring
- **Service accounts** - Minimal required permissions

### Access Control
- **RBAC** - Kubernetes role-based access control
- **Service accounts** - Dedicated monitoring service account
- **Network policies** - Pod-to-pod communication control

## Maintenance

### Backup
- **Configuration backup** - All config files in Git
- **Data backup** - Consider persistent volumes for production

### Updates
- **Regular updates** - Keep container images updated
- **Security patches** - Monitor for security updates
- **Configuration drift** - Use Ansible for consistency

## Troubleshooting

### Common Issues
1. **VM not accessible** - Check firewall rules and network configuration
2. **Services not starting** - Check Docker logs and resource availability
3. **Metrics not appearing** - Verify service discovery and scrape configs
4. **Logs not flowing** - Check Promtail configuration and file permissions

### Diagnostic Commands
```bash
# Check VM status
gcloud compute instances list --project=rizzup-dev

# Check container status
docker-compose ps

# Check Kubernetes pods
kubectl get pods -n monitoring

# Check service endpoints
kubectl get endpoints -n monitoring
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

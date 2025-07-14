#!/bin/bash

# GCP Monitoring Infrastructure Deployment Script
# This script deploys the complete monitoring stack for GKE monitoring

set -e

PROJECT_ID="rizzup-de"
REGION="us-central1"
ZONE="us-central1-a"
MONITORING_NAMESPACE="monitoring"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if terraform is installed
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install Terraform first."
        exit 1
    fi
    
    # Check if ansible is installed
    if ! command -v ansible-playbook &> /dev/null; then
        print_error "Ansible is not installed. Please install Ansible first."
        exit 1
    fi
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install kubectl first."
        exit 1
    fi
    
    # Check if gcloud is installed
    if ! command -v gcloud &> /dev/null; then
        print_error "gcloud CLI is not installed. Please install gcloud CLI first."
        exit 1
    fi
    
    print_status "All prerequisites are met."
}

# Deploy GCP infrastructure
deploy_infrastructure() {
    print_status "Deploying GCP infrastructure..."
    
    cd terraform
    
    # Initialize Terraform
    terraform init
    
    # Plan the deployment
    terraform plan -var="project_id=$PROJECT_ID" -var="region=$REGION" -var="zone=$ZONE"
    
    # Apply the configuration
    terraform apply -auto-approve -var="project_id=$PROJECT_ID" -var="region=$REGION" -var="zone=$ZONE"
    
    # Get the VM IP
    VM_IP=$(terraform output -raw monitoring_vm_external_ip)
    echo "VM_IP=$VM_IP" > ../vm_ip.env
    
    cd ..
    
    print_status "Infrastructure deployed successfully. VM IP: $VM_IP"
}

# Configure monitoring stack with Ansible
configure_monitoring() {
    print_status "Configuring monitoring stack with Ansible..."
    
    # Source the VM IP
    source vm_ip.env
    
    # Update the inventory file
    sed -i "s/MONITORING_VM_IP/$VM_IP/g" ansible/inventory/hosts
    
    cd ansible
    
    # Wait for VM to be ready
    print_status "Waiting for VM to be ready..."
    sleep 60
    
    # Test connectivity
    ansible -i inventory/hosts monitoring -m ping
    
    # Deploy the monitoring stack
    ansible-playbook -i inventory/hosts playbooks/monitoring.yml
    
    cd ..
    
    print_status "Monitoring stack configured successfully."
}

# Deploy Kubernetes components
deploy_kubernetes() {
    print_status "Deploying Kubernetes monitoring components..."
    
    cd kubernetes
    
    # Apply the manifests
    kubectl apply -f manifests/namespace.yaml
    kubectl apply -f manifests/prometheus.yaml
    kubectl apply -f manifests/grafana.yaml
    kubectl apply -f manifests/loki.yaml
    kubectl apply -f manifests/promtail.yaml
    kubectl apply -f manifests/otel-collector.yaml
    kubectl apply -f manifests/jaeger.yaml
    
    # Wait for pods to be ready
    print_status "Waiting for pods to be ready..."
    kubectl wait --for=condition=Ready pod -l app=prometheus -n $MONITORING_NAMESPACE --timeout=300s
    kubectl wait --for=condition=Ready pod -l app=grafana -n $MONITORING_NAMESPACE --timeout=300s
    kubectl wait --for=condition=Ready pod -l app=loki -n $MONITORING_NAMESPACE --timeout=300s
    kubectl wait --for=condition=Ready pod -l app=otel-collector -n $MONITORING_NAMESPACE --timeout=300s
    kubectl wait --for=condition=Ready pod -l app=jaeger -n $MONITORING_NAMESPACE --timeout=300s
    
    cd ..
    
    print_status "Kubernetes components deployed successfully."
}

# Display access information
display_access_info() {
    print_status "Deployment completed successfully!"
    
    source vm_ip.env
    
    echo ""
    echo "=== ACCESS INFORMATION ==="
    echo "VM-based Services:"
    echo "  Grafana:    http://$VM_IP:3000 (admin/admin)"
    echo "  Prometheus: http://$VM_IP:9090"
    echo "  Loki:       http://$VM_IP:3100"
    echo "  Jaeger:     http://$VM_IP:16686"
    echo ""
    echo "Kubernetes Services:"
    echo "  kubectl get services -n $MONITORING_NAMESPACE"
    echo ""
    echo "To access Grafana in Kubernetes:"
    echo "  kubectl port-forward svc/grafana 3000:3000 -n $MONITORING_NAMESPACE"
    echo ""
    echo "To check pod status:"
    echo "  kubectl get pods -n $MONITORING_NAMESPACE"
    echo ""
}

# Main execution
main() {
    print_status "Starting GCP Monitoring Infrastructure deployment..."
    
    check_prerequisites
    deploy_infrastructure
    configure_monitoring
    deploy_kubernetes
    display_access_info
    
    print_status "Deployment completed successfully!"
}

# Parse command line arguments
case "${1:-}" in
    "infrastructure")
        check_prerequisites
        deploy_infrastructure
        ;;
    "monitoring")
        configure_monitoring
        ;;
    "kubernetes")
        deploy_kubernetes
        ;;
    "info")
        display_access_info
        ;;
    *)
        main
        ;;
esac
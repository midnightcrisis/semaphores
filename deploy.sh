#!/bin/bash

# Deploy GCP Monitoring Infrastructure
# This script deploys VM with Terraform and configures monitoring stack with Ansible

set -e

# Configuration
PROJECT_ID="rizzup-dev"
REGION="us-central1"
ZONE="us-central1-c"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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
    
    # Check if gcloud is installed
    if ! command -v gcloud &> /dev/null; then
        print_error "gcloud CLI is not installed"
        exit 1
    fi
    
    # Check if terraform is installed
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed"
        exit 1
    fi
    
    # Check if ansible is installed
    if ! command -v ansible &> /dev/null; then
        print_error "Ansible is not installed"
        exit 1
    fi
    
    # Check if SSH key exists
    if [[ ! -f ~/.ssh/id_rsa.pub ]]; then
        print_error "SSH public key not found at ~/.ssh/id_rsa.pub"
        print_status "Generate SSH key with: ssh-keygen -t rsa -b 4096"
        exit 1
    fi
    
    print_status "All prerequisites check passed!"
}

# Setup GCP authentication
setup_gcp_auth() {
    print_status "Setting up GCP authentication..."
    
    # Set project
    gcloud config set project $PROJECT_ID
    
    # Check if authenticated
    if ! gcloud auth list --format="value(account)" | grep -q "@"; then
        print_status "Please authenticate with GCP:"
        gcloud auth login
    fi
    
    # Enable required APIs
    print_status "Enabling required GCP APIs..."
    gcloud services enable compute.googleapis.com
    gcloud services enable container.googleapis.com
    gcloud services enable monitoring.googleapis.com
    gcloud services enable logging.googleapis.com
}

# Deploy infrastructure with Terraform
deploy_infrastructure() {
    print_status "Deploying infrastructure with Terraform..."
    
    cd terraform
    
    # Initialize Terraform
    terraform init
    
    # Plan deployment
    terraform plan -var="project_id=$PROJECT_ID" -var="region=$REGION" -var="zone=$ZONE"
    
    # Apply changes
    terraform apply -auto-approve -var="project_id=$PROJECT_ID" -var="region=$REGION" -var="zone=$ZONE"
    
    # Get VM IP
    VM_IP=$(terraform output -raw vm_external_ip)
    print_status "VM deployed with IP: $VM_IP"
    
    cd ..
    
    # Update Ansible inventory
    sed -i "s/MONITORING_VM_IP/$VM_IP/g" ansible/inventory/hosts.ini
}

# Deploy monitoring stack with Ansible
deploy_monitoring() {
    print_status "Deploying monitoring stack with Ansible..."
    
    # Wait for VM to be ready
    print_status "Waiting for VM to be ready..."
    sleep 60
    
    # Install ansible requirements
    ansible-galaxy collection install community.docker
    
    # Run Ansible playbook
    cd ansible
    ansible-playbook -i inventory/hosts.ini playbooks/deploy-monitoring.yml
    cd ..
}

# Main deployment function
main() {
    print_status "Starting GCP Monitoring Infrastructure deployment..."
    
    check_prerequisites
    setup_gcp_auth
    deploy_infrastructure
    deploy_monitoring
    
    print_status "Deployment completed successfully!"
    print_status "Access your monitoring services:"
    echo "  - Grafana: http://$VM_IP:3000 (admin/admin123)"
    echo "  - Prometheus: http://$VM_IP:9090"
    echo "  - Loki: http://$VM_IP:3100"
    echo "  - Jaeger: http://$VM_IP:16686"
    echo "  - OpenTelemetry: http://$VM_IP:4317"
}

# Run main function
main "$@"
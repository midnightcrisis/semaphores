#!/bin/bash

# Cleanup GCP Monitoring Infrastructure
# This script destroys the infrastructure created by deploy.sh

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

# Confirm cleanup
confirm_cleanup() {
    print_warning "This will destroy ALL monitoring infrastructure in project: $PROJECT_ID"
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Cleanup cancelled."
        exit 0
    fi
}

# Cleanup Terraform resources
cleanup_terraform() {
    print_status "Destroying Terraform infrastructure..."
    
    cd terraform
    
    # Destroy resources
    terraform destroy -auto-approve -var="project_id=$PROJECT_ID" -var="region=$REGION" -var="zone=$ZONE"
    
    print_status "Terraform resources destroyed."
    
    cd ..
}

# Reset Ansible inventory
reset_ansible_inventory() {
    print_status "Resetting Ansible inventory..."
    
    # Reset inventory file
    sed -i 's/[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/MONITORING_VM_IP/g' ansible/inventory/hosts.ini
    
    print_status "Ansible inventory reset."
}

# Main cleanup function
main() {
    print_status "Starting GCP Monitoring Infrastructure cleanup..."
    
    confirm_cleanup
    cleanup_terraform
    reset_ansible_inventory
    
    print_status "Cleanup completed successfully!"
    print_status "All monitoring infrastructure has been destroyed."
}

# Run main function
main "$@"
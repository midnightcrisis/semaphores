#!/bin/bash

# Setup GKE Monitoring
# This script configures monitoring agents on GKE cluster

set -e

# Configuration
PROJECT_ID="rizzup-dev"
CLUSTER_NAME=""
ZONE=""
MONITORING_VM_IP=""

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

# Usage function
usage() {
    echo "Usage: $0 -c CLUSTER_NAME -z ZONE -i MONITORING_VM_IP"
    echo "  -c: GKE cluster name"
    echo "  -z: GKE cluster zone"
    echo "  -i: Monitoring VM IP address"
    echo "  -h: Show this help message"
    exit 1
}

# Parse command line arguments
while getopts "c:z:i:h" opt; do
    case $opt in
        c) CLUSTER_NAME="$OPTARG";;
        z) ZONE="$OPTARG";;
        i) MONITORING_VM_IP="$OPTARG";;
        h) usage;;
        \?) print_error "Invalid option: -$OPTARG"; usage;;
    esac
done

# Validate required parameters
if [[ -z "$CLUSTER_NAME" || -z "$ZONE" || -z "$MONITORING_VM_IP" ]]; then
    print_error "Missing required parameters"
    usage
fi

# Get GKE credentials
get_gke_credentials() {
    print_status "Getting GKE cluster credentials..."
    gcloud container clusters get-credentials "$CLUSTER_NAME" --zone="$ZONE" --project="$PROJECT_ID"
}

# Update monitoring configuration
update_monitoring_config() {
    print_status "Updating monitoring configuration..."
    
    # Update Promtail configuration with VM IP
    sed -i "s/MONITORING_VM_IP/$MONITORING_VM_IP/g" k8s/monitoring-agents.yml
    
    print_status "Configuration updated with monitoring VM IP: $MONITORING_VM_IP"
}

# Deploy monitoring agents
deploy_monitoring_agents() {
    print_status "Deploying monitoring agents to GKE cluster..."
    
    # Apply the monitoring configuration
    kubectl apply -f k8s/monitoring-agents.yml
    
    # Wait for pods to be ready
    print_status "Waiting for monitoring pods to be ready..."
    kubectl wait --for=condition=ready pod -l name=promtail -n monitoring --timeout=300s
    kubectl wait --for=condition=ready pod -l app=otel-collector -n monitoring --timeout=300s
    
    print_status "Monitoring agents deployed successfully!"
}

# Verify deployment
verify_deployment() {
    print_status "Verifying monitoring deployment..."
    
    # Check pod status
    kubectl get pods -n monitoring
    
    # Check services
    kubectl get services -n monitoring
    
    print_status "Monitoring deployment verification complete!"
}

# Main function
main() {
    print_status "Setting up GKE monitoring for cluster: $CLUSTER_NAME"
    
    get_gke_credentials
    update_monitoring_config
    deploy_monitoring_agents
    verify_deployment
    
    print_status "GKE monitoring setup completed successfully!"
    print_status "Your GKE cluster is now sending logs and traces to:"
    echo "  - Logs: http://$MONITORING_VM_IP:3100"
    echo "  - Traces: http://$MONITORING_VM_IP:4317"
    echo "  - Grafana: http://$MONITORING_VM_IP:3000"
}

# Run main function
main "$@"
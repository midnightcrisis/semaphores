#!/bin/bash

# GKE Cluster Setup Script for Monitoring
# This script sets up the GKE cluster for monitoring

set -e

PROJECT_ID="rizzup-de"
CLUSTER_NAME="monitoring-cluster"
REGION="us-central1"
MONITORING_NAMESPACE="monitoring"

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

# Check if GKE cluster exists
check_gke_cluster() {
    print_status "Checking GKE cluster..."
    
    if gcloud container clusters describe $CLUSTER_NAME --region=$REGION --project=$PROJECT_ID &> /dev/null; then
        print_status "GKE cluster '$CLUSTER_NAME' already exists."
        return 0
    else
        print_warning "GKE cluster '$CLUSTER_NAME' does not exist. Please create it first."
        return 1
    fi
}

# Connect to GKE cluster
connect_to_cluster() {
    print_status "Connecting to GKE cluster..."
    
    gcloud container clusters get-credentials $CLUSTER_NAME --region=$REGION --project=$PROJECT_ID
    
    # Verify connection
    if kubectl cluster-info &> /dev/null; then
        print_status "Successfully connected to GKE cluster."
    else
        print_error "Failed to connect to GKE cluster."
        exit 1
    fi
}

# Setup monitoring namespace
setup_monitoring_namespace() {
    print_status "Setting up monitoring namespace..."
    
    # Create namespace if it doesn't exist
    if ! kubectl get namespace $MONITORING_NAMESPACE &> /dev/null; then
        kubectl create namespace $MONITORING_NAMESPACE
        print_status "Created monitoring namespace."
    else
        print_status "Monitoring namespace already exists."
    fi
    
    # Label the namespace
    kubectl label namespace $MONITORING_NAMESPACE purpose=monitoring --overwrite
}

# Setup RBAC for monitoring
setup_rbac() {
    print_status "Setting up RBAC for monitoring..."
    
    # Apply the namespace and RBAC configuration
    kubectl apply -f kubernetes/manifests/namespace.yaml
    
    print_status "RBAC setup completed."
}

# Deploy monitoring components
deploy_monitoring_components() {
    print_status "Deploying monitoring components..."
    
    # Deploy each component
    components=(
        "prometheus"
        "grafana"
        "loki"
        "promtail"
        "otel-collector"
        "jaeger"
    )
    
    for component in "${components[@]}"; do
        print_status "Deploying $component..."
        kubectl apply -f kubernetes/manifests/$component.yaml
        
        # Wait for deployment to be ready
        if kubectl get deployment $component -n $MONITORING_NAMESPACE &> /dev/null; then
            kubectl wait --for=condition=available --timeout=300s deployment/$component -n $MONITORING_NAMESPACE
        fi
    done
    
    print_status "All monitoring components deployed."
}

# Verify deployment
verify_deployment() {
    print_status "Verifying deployment..."
    
    # Check pod status
    print_status "Checking pod status..."
    kubectl get pods -n $MONITORING_NAMESPACE
    
    # Check service status
    print_status "Checking service status..."
    kubectl get services -n $MONITORING_NAMESPACE
    
    # Check for any issues
    failed_pods=$(kubectl get pods -n $MONITORING_NAMESPACE --field-selector=status.phase!=Running --no-headers 2>/dev/null | wc -l)
    if [ "$failed_pods" -gt 0 ]; then
        print_warning "Some pods are not running. Check the pod status above."
    else
        print_status "All pods are running successfully."
    fi
}

# Setup port forwarding for access
setup_port_forwarding() {
    print_status "Setting up port forwarding for local access..."
    
    cat << EOF > port-forward.sh
#!/bin/bash
# Port forwarding script for monitoring services

echo "Starting port forwarding for monitoring services..."
echo "Access URLs:"
echo "  Grafana: http://localhost:3000"
echo "  Prometheus: http://localhost:9090"
echo "  Loki: http://localhost:3100"
echo "  Jaeger: http://localhost:16686"
echo ""
echo "Press Ctrl+C to stop port forwarding."

# Start port forwarding in background
kubectl port-forward svc/grafana 3000:3000 -n $MONITORING_NAMESPACE &
kubectl port-forward svc/prometheus 9090:9090 -n $MONITORING_NAMESPACE &
kubectl port-forward svc/loki 3100:3100 -n $MONITORING_NAMESPACE &
kubectl port-forward svc/jaeger 16686:16686 -n $MONITORING_NAMESPACE &

# Wait for user to stop
wait
EOF

    chmod +x port-forward.sh
    print_status "Port forwarding script created: port-forward.sh"
}

# Main execution
main() {
    print_status "Starting GKE cluster setup for monitoring..."
    
    check_gke_cluster
    connect_to_cluster
    setup_monitoring_namespace
    setup_rbac
    deploy_monitoring_components
    verify_deployment
    setup_port_forwarding
    
    print_status "GKE cluster setup completed!"
    print_status "Run './port-forward.sh' to access services locally."
}

# Parse command line arguments
case "${1:-}" in
    "connect")
        connect_to_cluster
        ;;
    "namespace")
        setup_monitoring_namespace
        ;;
    "rbac")
        setup_rbac
        ;;
    "deploy")
        deploy_monitoring_components
        ;;
    "verify")
        verify_deployment
        ;;
    "port-forward")
        setup_port_forwarding
        ;;
    *)
        main
        ;;
esac
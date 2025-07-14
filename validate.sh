#!/bin/bash

# Validation script for GCP Monitoring Infrastructure
# This script validates the deployment of the monitoring stack

set -e

PROJECT_ID="rizzup-de"
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

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Validate Terraform deployment
validate_terraform() {
    print_status "Validating Terraform deployment..."
    
    if [ ! -f "terraform/terraform.tfstate" ]; then
        print_error "Terraform state file not found. Please deploy infrastructure first."
        return 1
    fi
    
    cd terraform
    
    # Check if VM is running
    VM_NAME=$(terraform output -raw monitoring_vm_name 2>/dev/null || echo "")
    if [ -z "$VM_NAME" ]; then
        print_error "VM name not found in Terraform output."
        cd ..
        return 1
    fi
    
    # Check VM status
    VM_STATUS=$(gcloud compute instances describe $VM_NAME --zone=us-central1-a --project=$PROJECT_ID --format="value(status)" 2>/dev/null || echo "")
    if [ "$VM_STATUS" != "RUNNING" ]; then
        print_error "VM is not running. Current status: $VM_STATUS"
        cd ..
        return 1
    fi
    
    cd ..
    print_success "Terraform deployment validated successfully."
}

# Validate VM services
validate_vm_services() {
    print_status "Validating VM services..."
    
    if [ ! -f "vm_ip.env" ]; then
        print_error "VM IP file not found. Please deploy infrastructure first."
        return 1
    fi
    
    source vm_ip.env
    
    # Check if services are responding
    services=(
        "3000:Grafana"
        "9090:Prometheus"
        "3100:Loki"
        "4317:OpenTelemetry"
    )
    
    for service in "${services[@]}"; do
        port=$(echo $service | cut -d: -f1)
        name=$(echo $service | cut -d: -f2)
        
        if curl -s --connect-timeout 5 "http://$VM_IP:$port" > /dev/null; then
            print_success "$name service is responding on port $port"
        else
            print_warning "$name service is not responding on port $port"
        fi
    done
}

# Validate Kubernetes deployment
validate_kubernetes() {
    print_status "Validating Kubernetes deployment..."
    
    # Check if namespace exists
    if ! kubectl get namespace $MONITORING_NAMESPACE &> /dev/null; then
        print_error "Monitoring namespace does not exist."
        return 1
    fi
    
    # Check pod status
    pods=(
        "prometheus"
        "grafana"
        "loki"
        "otel-collector"
        "jaeger"
    )
    
    for pod in "${pods[@]}"; do
        if kubectl get pods -n $MONITORING_NAMESPACE -l app=$pod --no-headers 2>/dev/null | grep -q "Running"; then
            print_success "$pod pod is running"
        else
            print_warning "$pod pod is not running or not found"
        fi
    done
    
    # Check services
    services=(
        "prometheus"
        "grafana"
        "loki"
        "otel-collector"
        "jaeger"
    )
    
    for service in "${services[@]}"; do
        if kubectl get service $service -n $MONITORING_NAMESPACE &> /dev/null; then
            print_success "$service service exists"
        else
            print_warning "$service service does not exist"
        fi
    done
}

# Validate monitoring data flow
validate_monitoring_data() {
    print_status "Validating monitoring data flow..."
    
    if [ ! -f "vm_ip.env" ]; then
        print_error "VM IP file not found."
        return 1
    fi
    
    source vm_ip.env
    
    # Check Prometheus targets
    if curl -s "http://$VM_IP:9090/api/v1/targets" | grep -q "\"health\":\"up\""; then
        print_success "Prometheus has healthy targets"
    else
        print_warning "Prometheus may not have healthy targets"
    fi
    
    # Check Loki readiness
    if curl -s "http://$VM_IP:3100/ready" | grep -q "ready"; then
        print_success "Loki is ready"
    else
        print_warning "Loki may not be ready"
    fi
    
    # Check Grafana health
    if curl -s "http://$VM_IP:3000/api/health" | grep -q "ok"; then
        print_success "Grafana is healthy"
    else
        print_warning "Grafana may not be healthy"
    fi
}

# Generate validation report
generate_report() {
    print_status "Generating validation report..."
    
    echo "=== VALIDATION REPORT ===" > validation_report.txt
    echo "Date: $(date)" >> validation_report.txt
    echo "" >> validation_report.txt
    
    # Terraform validation
    echo "## Terraform Deployment" >> validation_report.txt
    if validate_terraform &> /dev/null; then
        echo "✓ Terraform deployment: PASSED" >> validation_report.txt
    else
        echo "✗ Terraform deployment: FAILED" >> validation_report.txt
    fi
    
    # VM services validation
    echo "## VM Services" >> validation_report.txt
    if validate_vm_services &> /dev/null; then
        echo "✓ VM services: PASSED" >> validation_report.txt
    else
        echo "✗ VM services: FAILED" >> validation_report.txt
    fi
    
    # Kubernetes validation
    echo "## Kubernetes Deployment" >> validation_report.txt
    if validate_kubernetes &> /dev/null; then
        echo "✓ Kubernetes deployment: PASSED" >> validation_report.txt
    else
        echo "✗ Kubernetes deployment: FAILED" >> validation_report.txt
    fi
    
    # Monitoring data validation
    echo "## Monitoring Data Flow" >> validation_report.txt
    if validate_monitoring_data &> /dev/null; then
        echo "✓ Monitoring data flow: PASSED" >> validation_report.txt
    else
        echo "✗ Monitoring data flow: FAILED" >> validation_report.txt
    fi
    
    echo "" >> validation_report.txt
    echo "=== END REPORT ===" >> validation_report.txt
    
    print_success "Validation report generated: validation_report.txt"
}

# Main execution
main() {
    print_status "Starting validation of GCP Monitoring Infrastructure..."
    
    validate_terraform
    validate_vm_services
    validate_kubernetes
    validate_monitoring_data
    generate_report
    
    print_success "Validation completed!"
}

# Parse command line arguments
case "${1:-}" in
    "terraform")
        validate_terraform
        ;;
    "vm")
        validate_vm_services
        ;;
    "kubernetes")
        validate_kubernetes
        ;;
    "data")
        validate_monitoring_data
        ;;
    "report")
        generate_report
        ;;
    *)
        main
        ;;
esac
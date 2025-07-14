#!/bin/bash

# Test GCP Monitoring Infrastructure
# This script tests the deployed monitoring stack

set -e

# Configuration
MONITORING_VM_IP=""
TIMEOUT=30

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

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Usage function
usage() {
    echo "Usage: $0 -i MONITORING_VM_IP"
    echo "  -i: Monitoring VM IP address"
    echo "  -h: Show this help message"
    exit 1
}

# Parse command line arguments
while getopts "i:h" opt; do
    case $opt in
        i) MONITORING_VM_IP="$OPTARG";;
        h) usage;;
        \?) print_error "Invalid option: -$OPTARG"; usage;;
    esac
done

# Validate required parameters
if [[ -z "$MONITORING_VM_IP" ]]; then
    print_error "Missing required parameter: MONITORING_VM_IP"
    usage
fi

# Test service availability
test_service() {
    local service_name=$1
    local port=$2
    local path=${3:-""}
    
    print_status "Testing $service_name service..."
    
    if curl -s --max-time $TIMEOUT -o /dev/null -w "%{http_code}" "http://$MONITORING_VM_IP:$port$path" | grep -q "200\|404"; then
        print_success "$service_name is accessible"
        return 0
    else
        print_error "$service_name is not accessible"
        return 1
    fi
}

# Test all monitoring services
test_monitoring_services() {
    print_status "Testing monitoring services on VM: $MONITORING_VM_IP"
    
    local failed=0
    
    # Test Grafana
    test_service "Grafana" 3000 "/login" || ((failed++))
    
    # Test Prometheus
    test_service "Prometheus" 9090 "/graph" || ((failed++))
    
    # Test Loki
    test_service "Loki" 3100 "/ready" || ((failed++))
    
    # Test Jaeger
    test_service "Jaeger" 16686 || ((failed++))
    
    # Test OpenTelemetry Collector
    test_service "OpenTelemetry Collector" 4317 || ((failed++))
    
    # Test AlertManager
    test_service "AlertManager" 9093 || ((failed++))
    
    if [[ $failed -eq 0 ]]; then
        print_success "All monitoring services are accessible!"
    else
        print_error "$failed monitoring services failed accessibility test"
        return 1
    fi
}

# Test Prometheus targets
test_prometheus_targets() {
    print_status "Testing Prometheus targets..."
    
    local targets_response=$(curl -s --max-time $TIMEOUT "http://$MONITORING_VM_IP:9090/api/v1/targets" 2>/dev/null)
    
    if echo "$targets_response" | grep -q '"status":"success"'; then
        print_success "Prometheus targets are accessible"
        
        # Count active targets
        local active_targets=$(echo "$targets_response" | jq '.data.activeTargets | length' 2>/dev/null || echo "0")
        print_status "Active targets: $active_targets"
    else
        print_error "Failed to query Prometheus targets"
        return 1
    fi
}

# Test Loki logs
test_loki_logs() {
    print_status "Testing Loki log ingestion..."
    
    local query_response=$(curl -s --max-time $TIMEOUT "http://$MONITORING_VM_IP:3100/loki/api/v1/query?query={job=~\".*\"}" 2>/dev/null)
    
    if echo "$query_response" | grep -q '"status":"success"'; then
        print_success "Loki is receiving logs"
    else
        print_warning "Loki may not be receiving logs yet (this is normal for new deployments)"
    fi
}

# Generate summary report
generate_report() {
    print_status "Generating monitoring stack summary..."
    
    echo ""
    echo "=== MONITORING STACK SUMMARY ==="
    echo "VM IP: $MONITORING_VM_IP"
    echo ""
    echo "Service URLs:"
    echo "  - Grafana:     http://$MONITORING_VM_IP:3000"
    echo "  - Prometheus:  http://$MONITORING_VM_IP:9090"
    echo "  - Loki:        http://$MONITORING_VM_IP:3100"
    echo "  - Jaeger:      http://$MONITORING_VM_IP:16686"
    echo "  - OTEL:        http://$MONITORING_VM_IP:4317"
    echo "  - AlertManager: http://$MONITORING_VM_IP:9093"
    echo ""
    echo "Default Credentials:"
    echo "  - Grafana: admin/admin123"
    echo ""
    echo "Next Steps:"
    echo "  1. Access Grafana dashboard"
    echo "  2. Configure data sources"
    echo "  3. Import dashboards"
    echo "  4. Setup GKE monitoring with: ./setup-gke-monitoring.sh"
    echo "=================================="
}

# Main function
main() {
    print_status "Starting monitoring infrastructure test..."
    
    test_monitoring_services
    test_prometheus_targets
    test_loki_logs
    generate_report
    
    print_success "Monitoring infrastructure test completed!"
}

# Run main function
main "$@"
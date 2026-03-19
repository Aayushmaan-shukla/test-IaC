#!/bin/bash

##############################################################################
# add-api-monitoring.sh
#
# Helper script for adding new API monitoring targets to Prometheus
# This script creates JSON files for Prometheus file-based service discovery
#
# Usage: ./scripts/add-api-monitoring.sh
##############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SD_DIR="$PROJECT_ROOT/config/prometheus-file-sd"

# Default values
DEFAULT_SCRAPE_INTERVAL="15s"
DEFAULT_METRICS_PATH="/metrics"

##############################################################################
# Functions
##############################################################################

print_header() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

validate_json() {
    local json_file="$1"

    if ! command -v jq &> /dev/null; then
        print_warning "jq not found - skipping JSON validation"
        return 0
    fi

    if jq empty "$json_file" 2>/dev/null; then
        print_success "JSON is valid"
        return 0
    else
        print_error "JSON validation failed"
        return 1
    fi
}

reload_prometheus() {
    print_info "Attempting to reload Prometheus..."

    # Check if Prometheus container is running
    if docker ps --format '{{.Names}}' | grep -q '^prometheus$'; then
        # Send SIGHUP to reload Prometheus
        docker kill -s HUP prometheus &> /dev/null && \
            print_success "Prometheus reloaded successfully" || \
            print_warning "Could not reload Prometheus - changes will take effect on next restart"
    else
        print_warning "Prometheus container is not running - changes will take effect on next start"
    fi
}

show_examples() {
    print_header "API Monitoring Examples"

    echo -e "\n${GREEN}Example 1: Simple REST API with no authentication${NC}"
    cat << 'EOF'
{
  "targets": ["api.example.com:8080"],
  "labels": {
    "job": "example-api",
    "env": "production",
    "metrics_path": "/metrics"
  }
}
EOF

    echo -e "\n${GREEN}Example 2: API with Basic Authentication${NC}"
    cat << 'EOF'
{
  "targets": ["api.example.com:8080"],
  "labels": {
    "job": "example-api",
    "env": "production",
    "metrics_path": "/metrics",
    "auth_type": "basic",
    "auth_username": "admin",
    "auth_password": "secret"
  }
}
EOF

    echo -e "\n${GREEN}Example 3: API with Bearer Token${NC}"
    cat << 'EOF'
{
  "targets": ["api.example.com:8080"],
  "labels": {
    "job": "example-api",
    "env": "production",
    "metrics_path": "/metrics",
    "auth_type": "bearer",
    "auth_token": "your-bearer-token-here"
  }
}
EOF

    echo -e "\n${GREEN}Example 4: Multiple API instances (load balanced)${NC}"
    cat << 'EOF'
{
  "targets": [
    "api1.example.com:8080",
    "api2.example.com:8080",
    "api3.example.com:8080"
  ],
  "labels": {
    "job": "example-api",
    "env": "production",
    "metrics_path": "/metrics"
  }
}
EOF

    echo -e "\n${GREEN}Example 5: API with custom scrape interval (via relabeling)${NC}"
    cat << 'EOF'
{
  "targets": ["api.example.com:8080"],
  "labels": {
    "job": "example-api",
    "env": "production",
    "metrics_path": "/metrics",
    "scrape_interval": "30s",
    "scrape_timeout": "10s"
  }
}
EOF
}

##############################################################################
# Main Script
##############################################################################

print_header "Add API Monitoring to Prometheus"

# Check if service discovery directory exists
if [ ! -d "$SD_DIR" ]; then
    print_error "Service discovery directory not found: $SD_DIR"
    print_info "Please run the monitoring stack setup first"
    exit 1
fi

# Check if docker is running
if ! docker info &> /dev/null; then
    print_error "Docker is not running"
    exit 1
fi

# Show examples if requested
if [ "$1" = "--examples" ] || [ "$1" = "-e" ]; then
    show_examples
    exit 0
fi

echo -e "\n${GREEN}This script will help you add a new API for monitoring${NC}"
echo -e "Run with --examples to see configuration examples\n"

# Collect API information
read -p "Enter API name (e.g., user-api, payment-api): " api_name

if [ -z "$api_name" ]; then
    print_error "API name is required"
    exit 1
fi

# Sanitize API name for filename
api_filename=$(echo "$api_name" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
output_file="$SD_DIR/api-${api_filename}.json"

# Check if file already exists
if [ -f "$output_file" ]; then
    print_warning "File already exists: $output_file"
    read -p "Overwrite? (y/N): " overwrite

    if [ "$overwrite" != "y" ] && [ "$overwrite" != "Y" ]; then
        print_info "Operation cancelled"
        exit 0
    fi
fi

# Collect API endpoint(s)
echo -e "\nEnter API target(s) (comma-separated for multiple instances)"
echo -e "Example: api.example.com:8080 or api1.example.com:8080,api2.example.com:8080"
read -p "Target(s): " api_targets

if [ -z "$api_targets" ]; then
    print_error "API target is required"
    exit 1
fi

# Collect metrics path
read -p "Enter metrics path [default: /metrics]: " metrics_path
metrics_path="${metrics_path:-$DEFAULT_METRICS_PATH}"

# Collect environment label
read -p "Enter environment label (e.g., production, staging, development): " api_env

# Collect authentication type
echo -e "\n${GREEN}Select authentication type:${NC}"
echo "1) None (default)"
echo "2) Basic Authentication"
echo "3) Bearer Token"
read -p "Enter choice [1-3]: " auth_choice

auth_type="none"
auth_username=""
auth_password=""
auth_token=""

case $auth_choice in
    2)
        auth_type="basic"
        read -p "Enter username: " auth_username
        read -sp "Enter password: " auth_password
        echo ""
        ;;
    3)
        auth_type="bearer"
        read -p "Enter bearer token: " auth_token
        ;;
    *)
        auth_type="none"
        ;;
esac

# Collect additional labels
echo -e "\n${GREEN}Optional labels (press Enter to skip):${NC}"
read -p "Team (e.g., backend, platform): " team_label
read -p "Service (e.g., user-service, payment-service): " service_label
read -p "Region (e.g., us-east-1, eu-west-1): " region_label

# Build JSON configuration
print_info "Creating JSON configuration..."

# Convert comma-separated targets to JSON array
targets_array=$(echo "$api_targets" | jq -R 'split(",") | map(select(length > 0))')

# Build labels object
labels_json=$(cat << EOF
{
  "job": "$api_name",
  "metrics_path": "$metrics_path",
  "env": "${api_env:-unknown}"
}
EOF
)

# Add authentication labels if provided
if [ "$auth_type" != "none" ]; then
    labels_json=$(echo "$labels_json" | jq --arg type "$auth_type" '. + {"auth_type": $type}')

    if [ "$auth_type" = "basic" ]; then
        labels_json=$(echo "$labels_json" | jq --arg user "$auth_username" --arg pass "$auth_password" \
            '. + {"auth_username": $user, "auth_password": $pass}')
    elif [ "$auth_type" = "bearer" ]; then
        labels_json=$(echo "$labels_json" | jq --arg token "$auth_token" '. + {"auth_token": $token}')
    fi
fi

# Add optional labels if provided
if [ -n "$team_label" ]; then
    labels_json=$(echo "$labels_json" | jq --arg team "$team_label" '. + {"team": $team}')
fi

if [ -n "$service_label" ]; then
    labels_json=$(echo "$labels_json" | jq --arg service "$service_label" '. + {"service": $service}')
fi

if [ -n "$region_label" ]; then
    labels_json=$(echo "$labels_json" | jq --arg region "$region_label" '. + {"region": $region}')
fi

# Combine targets and labels
final_json=$(cat << EOF
{
  "targets": $targets_array,
  "labels": $labels_json
}
EOF
)

# Write to file
echo "$final_json" | jq '.' > "$output_file"

# Validate JSON
if validate_json "$output_file"; then
    print_success "Configuration file created: $output_file"
else
    print_error "Failed to create valid JSON"
    rm -f "$output_file"
    exit 1
fi

# Show created configuration
echo -e "\n${GREEN}Configuration created:${NC}"
cat "$output_file"

# Offer to reload Prometheus
echo -e "\n${GREEN}Next steps:${NC}"
echo "1. The API will be monitored automatically (Prometheus uses file-based service discovery)"
echo "2. You can view the API in Prometheus UI: http://localhost:4102/targets"
echo "3. Create a dashboard in Grafana to visualize the metrics"

read -p $'\nReload Prometheus now? (y/N): ' reload_now

if [ "$reload_now" = "y" ] || [ "$reload_now" = "Y" ]; then
    reload_prometheus
else
    print_info "Prometheus will pick up the new API on its next reload"
fi

print_success "API monitoring configuration completed!"

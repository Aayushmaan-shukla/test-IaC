#!/bin/bash

# Terraform Provider Management Script
# Usage: ./add-provider.sh <provider-name>
# Examples: ./add-provider.sh azure, ./add-provider.sh hetzner

set -e

PROVIDER=$1

# Validate input
if [ -z "$PROVIDER" ]; then
    echo "Error: No provider specified"
    echo "Usage: $0 <provider-name>"
    echo "Example: $0 azure"
    exit 1
fi

# Convert to lowercase for consistency
PROVIDER=$(echo "$PROVIDER" | tr '[:upper:]' '[:lower:]')

echo "=== Adding $PROVIDER provider to Terraform setup ==="

# Check if provider already exists
if grep -q "\"${PROVIDER}\"" providers.conf 2>/dev/null; then
    echo "Error: Provider $PROVIDER already exists in providers.conf"
    exit 1
fi

# 1. Create providers.conf file if it doesn't exist
if [ ! -f "providers.conf" ]; then
    echo "Creating providers.conf file..."
    cat > providers.conf << 'EOF'
# Terraform Providers Configuration
# Format: [provider_name]
# enabled=true/false
# region/location=<value>
# Other provider-specific settings

EOF
fi

# 2. Add provider configuration to providers.conf
echo "Adding $PROVIDER to providers.conf..."

case "$PROVIDER" in
    "azure")
        cat >> providers.conf << EOF

[azure]
enabled=false
location=eastus
subscription_id=
resource_group_name=terraform-resources
ssh_public_key_path=~/.ssh/id_rsa.pub
module_path=./modules/network-azure
compute_module_path=./modules/compute-azure
EOF
        ;;
    "hetzner")
        cat >> providers.conf << EOF

[hetzner]
enabled=false
location=nbg1
token=
ssh_public_key_path=~/.ssh/id_rsa.pub
module_path=./modules/network-hetzner
compute_module_path=./modules/compute-hetzner
EOF
        ;;
    "gcp")
        cat >> providers.conf << EOF

[gcp]
enabled=false
region=us-central1
zone=us-central1-a
project_id=
credentials_path=
module_path=./modules/network-gcp
compute_module_path=./modules/compute-gcp
EOF
        ;;
    *)
        cat >> providers.conf << EOF

[$PROVIDER]
enabled=false
region=
token=
module_path=./modules/network-$PROVIDER
compute_module_path=./modules/compute-$PROVIDER
EOF
        ;;
esac

# 3. Update provider.tf with the new provider
echo "Updating provider.tf..."

case "$PROVIDER" in
    "azure")
        if ! grep -q "azurerm" provider.tf; then
            cat >> provider.tf << 'EOF'

# Azure Provider
provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
}

variable "azure_subscription_id" {
  type        = string
  default     = ""
  description = "Azure subscription ID"
  sensitive   = true
}

variable "azure_location" {
  type        = string
  default     = "eastus"
  description = "Azure region"
}

variable "azure_resource_group" {
  type        = string
  default     = "terraform-resources"
  description = "Azure resource group name"
}

variable "azure_ssh_public_key" {
  type        = string
  default     = ""
  description = "SSH public key for Azure VM access"
  sensitive   = true
}
EOF
        fi
        ;;
    "hetzner")
        if ! grep -q "hcloud" provider.tf; then
            cat >> provider.tf << 'EOF'

# Hetzner Cloud Provider
provider "hcloud" {
  token = var.hetzner_token
}

variable "hetzner_token" {
  type        = string
  default     = ""
  description = "Hetzner Cloud API token"
  sensitive   = true
}

variable "hetzner_location" {
  type        = string
  default     = "nbg1"
  description = "Hetzner datacenter location"
}

variable "hetzner_ssh_public_key" {
  type        = string
  default     = ""
  description = "SSH public key for Hetzner server access"
  sensitive   = true
}
EOF
        fi
        ;;
    "gcp")
        if ! grep -q "google" provider.tf; then
            cat >> provider.tf << 'EOF'

# Google Cloud Provider
provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
  zone    = var.gcp_zone
}

variable "gcp_project_id" {
  type        = string
  default     = ""
  description = "GCP project ID"
}

variable "gcp_region" {
  type        = string
  default     = "us-central1"
  description = "GCP region"
}

variable "gcp_zone" {
  type        = string
  default     = "us-central1-a"
  description = "GCP zone"
}

variable "gcp_credentials_path" {
  type        = string
  default     = ""
  description = "Path to GCP service account credentials file"
}
EOF
        fi
        ;;
esac

# 4. Update variables.tf for provider selection
echo "Updating variables.tf..."

if ! grep -q "cloud_provider" variables.tf; then
    cat >> variables.tf << 'EOF'

# Cloud provider selection
variable "cloud_provider" {
  type        = string
  default     = "aws"
  description = "Cloud provider: aws, azure, hetzner, gcp"
  validation {
    condition     = contains(["aws", "azure", "hetzner", "gcp"], var.cloud_provider)
    error_message = "Cloud provider must be one of: aws, azure, hetzner, gcp."
  }
}
EOF
fi

# 5. Create provider-specific modules
echo "Creating provider-specific modules..."

# Create network module
mkdir -p "modules/network-$PROVIDER"
cat > "modules/network-$PROVIDER/main.tf" << EOF
# Network module for $PROVIDER
# This module creates security groups/network resources for $PROVIDER
EOF

cat > "modules/network-$PROVIDER/variables.tf" << 'EOF'
variable "env_name" {
  type        = string
  description = "Environment name for tagging"
}

output "sg_id" {
  value = "security-group-id-placeholder"
  description = "Security group or network resource ID"
}
EOF

# Create compute module
mkdir -p "modules/compute-$PROVIDER"
cat > "modules/compute-$PROVIDER/main.tf" << EOF
# Compute module for $PROVIDER
# This module creates compute instances for $PROVIDER
EOF

cat > "modules/compute-$PROVIDER/variables.tf" << 'EOF'
variable "env_name" {
  type        = string
  description = "Environment name for tagging"
}

variable "server_name" {
  type        = string
  description = "Server name tag"
}

variable "instance_type" {
  type        = string
  description = "Instance/VM type"
}

output "instance_id" {
  value = "instance-id-placeholder"
}

output "public_ip" {
  value = "0.0.0.0"
}

output "private_ip" {
  value = "10.0.0.1"
}
EOF

# 6. Create provider-specific .tfvars files
echo "Creating provider-specific .tfvars files..."

cat > "$PROVIDER-dev.tfvars" << EOF
# Development environment for $PROVIDER
cloud_provider = "$PROVIDER"
env_name       = "dev"
server_name    = "${PROVIDER}-dev-server"
EOF

cat > "$PROVIDER-prod.tfvars" << EOF
# Production environment for $PROVIDER
cloud_provider = "$PROVIDER"
env_name       = "prod"
server_name    = "${PROVIDER}-prod-server"
EOF

# 7. Update main.tf for provider switching (if not already done)
echo "Checking main.tf for provider switching logic..."

if ! grep -q "cloud_provider" main.tf; then
    echo "Note: You may need to update main.tf to use conditional module selection"
    echo "Add logic like: source = \"./modules/compute-\${var.cloud_provider}\""
fi

# 8. Create provider-specific deployment script
cat > "deploy-$PROVIDER.sh" << EOF
#!/bin/bash

# Deployment script for $PROVIDER
# Usage: ./deploy-$PROVIDER.sh [dev|prod]

set -e

ENVIRONMENT=\${1:-dev}

echo "=== Deploying to $PROVIDER ($ENVIRONMENT environment) ==="

# Create workspace if it doesn't exist
terraform workspace list | grep -q "$PROVIDER-\$ENVIRONMENT" || terraform workspace new "$PROVIDER-\$ENVIRONMENT"

# Apply with provider-specific variables
terraform apply -var-file="$PROVIDER-\$ENVIRONMENT.tfvars"

echo "=== Deployment to $PROVIDER completed ==="
EOF

chmod +x "deploy-$PROVIDER.sh"

# 9. Create a README for the new provider
cat > "README-$PROVIDER.md" << EOF
# $PROVIDER Provider Setup Guide

## Configuration

The $PROVIDER provider has been added to your Terraform setup. Configuration is stored in \`providers.conf\`.

## Setup Steps

1. **Configure Provider Settings**:
   Edit \`providers.conf\` and update the \`[$PROVIDER]\` section with your credentials:
   - Set \`enabled=true\`
   - Add your subscription ID/token
   - Configure region/location
   - Set SSH public key path

2. **Install Provider Plugin**:
   \`\`\`bash
   terraform init
   \`\`\`

3. **Deploy to Development**:
   \`\`\`bash
   ./deploy-$PROVIDER.sh dev
   \`\`\`

4. **Deploy to Production**:
   \`\`\`bash
   ./deploy-$PROVIDER.sh prod
   \`\`\`

## Variables Files

- \`$PROVIDER-dev.tfvars\` - Development environment variables
- \`$PROVIDER-prod.tfvars\` - Production environment variables

## Modules Created

- \`modules/network-$PROVIDER/\` - Network/security resources
- \`modules/compute-$PROVIDER/\` - Compute instance resources

## Customization

You can customize the modules in:
- \`modules/network-$PROVIDER/main.tf\` - Network configuration
- \`modules/compute-$PROVIDER/main.tf\` - Compute configuration
EOF

echo ""
echo "=== $PROVIDER provider added successfully! ==="
echo ""
echo "Next steps:"
echo "1. Edit providers.conf and configure the [$PROVIDER] section"
echo "2. Run: terraform init"
echo "3. Deploy using: ./deploy-$PROVIDER.sh dev"
echo "4. For more details, see: README-$PROVIDER.md"
echo ""
echo "Files created/modified:"
echo "- providers.conf (updated)"
echo "- provider.tf (updated)"
echo "- variables.tf (updated)"
echo "- modules/network-$PROVIDER/ (created)"
echo "- modules/compute-$PROVIDER/ (created)"
echo "- $PROVIDER-dev.tfvars (created)"
echo "- $PROVIDER-prod.tfvars (created)"
echo "- deploy-$PROVIDER.sh (created)"
echo "- README-$PROVIDER.md (created)"

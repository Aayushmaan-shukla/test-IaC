# Terraform Infrastructure Guide

## Quick Overview

This Terraform setup uses a modular approach to deploy infrastructure across different environments and providers. The current setup supports AWS EC2 instances with security groups, and it's designed to be easily extended for additional cloud providers.

## Directory Structure

```
terraform/
├── backend.tf           # State management (S3)
├── provider.tf          # AWS provider configuration
├── main.tf              # Main orchestration
├── variables.tf         # Variable definitions
├── prod.tfvars         # Production environment values
└── modules/
    ├── network/         # AWS security groups
    └── compute/         # AWS EC2 instances
```

## How It Works

### Terraform Flow

1. **Initialize**: Terraform reads provider configurations from `provider.tf`
2. **State Management**: Uses S3 bucket `aayushmaan-terraform` for remote state
3. **Module Loading**: Loads network and compute modules from `modules/` directory
4. **Resource Creation**: Creates security groups first, then EC2 instances
5. **Outputs**: Returns instance IDs, IPs, and other important information

### Current AWS Setup

- **Region**: us-east-1
- **Instance Type**: t3.micro (default)
- **AMI**: Latest Ubuntu 22.04 (fetched dynamically)
- **Storage**: 60GB GP3 volume
- **Security**: SSH (22), HTTP (80), HTTPS (443) access from anywhere
- **Key Pair**: aayush-test

## Adding New Servers

### Quick Method: Create a tfvars File

1. **Create a new variables file** for your server:

```bash
cat > myserver.tfvars << EOF
env_name    = "dev"
server_name = "myserver"
EOF
```

2. **Create a workspace** for this deployment:

```bash
terraform workspace new myserver
```

3. **Deploy**:

```bash
terraform apply -var-file="myserver.tfvars"
```

### Alternative: Use Command Line Variables

```bash
terraform workspace new myserver
terraform apply -var="env_name=dev" -var="server_name=myserver"
```

### Example: Adding a Test Server

Let's say you want to add a server called `im_dev_test`:

1. **Create the variables file**:
```bash
cat > im_dev_test.tfvars << EOF
env_name    = "dev"
server_name = "im_dev_test"
EOF
```

2. **Set up the workspace**:
```bash
terraform workspace new im_dev_test
```

3. **Apply the configuration**:
```bash
terraform apply -var-file="im_dev_test.tfvars"
```

That's it! The server will be created with the name `im_dev_test` and tagged with `env=dev`.

## Adding New Environments/Providers

### Adding a New Provider (Like Azure or Hetzner)

To make it easy to add new providers, you should create a shell script that handles the setup. Here's what needs to happen:

#### 1. Provider Setup Script

Create `add-provider.sh` that automates provider addition:

```bash
#!/bin/bash
PROVIDER=$1

# This script would:
# - Add provider config to provider.tf
# - Create provider-specific modules
# - Create provider .tfvars files
# - Update variables.tf as needed
```

#### 2. Usage Examples

```bash
# Add Azure
./add-provider.sh azure

# Add Hetzner
./add-provider.sh hetzner

# Add GCP
./add-provider.sh gcp
```

#### 3. What Gets Created Automatically

For Azure, the script would create:
- `modules/network-azure/main.tf` - Azure network security groups
- `modules/compute-azure/main.tf` - Azure VM instances
- `azure-dev.tfvars` - Azure development configuration
- `azure-prod.tfvars` - Azure production configuration

### Multi-Provider Architecture

To support multiple providers, you'd modify a few key files:

**Update `variables.tf`**:
```hcl
variable "cloud_provider" {
  type        = string
  default     = "aws"
  description = "Cloud provider: aws, azure, hetzner, etc."
}
```

**Update `main.tf`** to use conditional module selection:
```hcl
module "network" {
  source   = "./modules/network-${var.cloud_provider}"
  env_name = local.env_name
}

module "compute" {
  source   = "./modules/compute-${var.cloud_provider}"
  # ... other variables
}
```

**Add provider to `provider.tf`**:
```hcl
provider "azurerm" {
  features {}
}

provider "hcloud" {
  token = var.hetzner_token
}
```

## Deployment Commands

### Basic Operations

```bash
# Initialize Terraform
terraform init

# Check what will be created
terraform plan

# Create infrastructure
terraform apply

# Destroy infrastructure
terraform destroy

# List workspaces
terraform workspace list

# Switch workspaces
terraform workspace select prod
```

### With Environment Variables

```bash
# Deploy to production
terraform workspace select prod
terraform apply -var-file="prod.tfvars"

# Deploy to development
terraform workspace new dev
terraform apply -var="env_name=dev" -var="server_name=dev-server"
```

## Understanding the Modules

### Network Module (`modules/network/`)

Creates a security group with:
- SSH access (port 22)
- HTTP access (port 80)
- HTTPS access (port 443)
- All outbound traffic allowed

### Compute Module (`modules/compute/`)

Creates an EC2 instance with:
- 60GB GP3 storage
- Ubuntu 22.04 AMI
- Configurable instance type
- Tags for environment and server name
- Security group attachment

## Troubleshooting

### Common Issues

**State Lock Issues**: If S3 state is locked:
```bash
terraform force-unlock <LOCK_ID>
```

**Provider Not Found**: Make sure to run:
```bash
terraform init
```

**Workspace Confusion**: Always check your current workspace:
```bash
terraform workspace show
```

## Best Practices

1. **Use Workspaces**: Create separate workspaces for different environments
2. **Use .tfvars Files**: Keep environment-specific values in separate files
3. **State Management**: Always use remote state for team collaboration
4. **Version Control**: Track all Terraform files in Git
5. **Plan Before Apply**: Always run `terraform plan` before `terraform apply`

## Future Improvements

Consider adding:
- Automated provider management script (`add-provider.sh`)
- Monitoring and logging setup
- Load balancer configuration
- Database modules
- CI/CD integration for automated deployments

---

This guide should help you manage servers and providers efficiently. The modular design makes it easy to add new cloud providers without rewriting everything from scratch.

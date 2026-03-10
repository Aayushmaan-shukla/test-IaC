# Provider Management System

This Terraform setup now includes a simplified provider management system that makes it easy to add and manage multiple cloud providers.

## How It Works

### Single Configuration File

All provider settings are managed in one place: **[providers.conf](providers.conf)**

This file acts as your central configuration hub for all cloud providers. You can enable/disable providers and set their credentials here.

### Automated Provider Setup

The **[add-provider.sh](add-provider.sh)** script automates everything when adding new providers:

- Creates provider-specific modules
- Adds provider configurations to Terraform files
- Generates deployment scripts
- Creates environment-specific variable files

## Quick Start

### Add a New Provider

```bash
# Add Azure provider
./add-provider.sh azure

# Add Hetzner provider
./add-provider.sh hetzner

# Add Google Cloud provider
./add-provider.sh gcp
```

### Configure Your Providers

After adding a provider, edit **[providers.conf](providers.conf)**:

```ini
[azure]
enabled=true
location=eastus
subscription_id=your-subscription-id
resource_group_name=terraform-resources
ssh_public_key_path=~/.ssh/id_rsa.pub
```

### Deploy to a Provider

Each provider gets its own deployment script:

```bash
# Deploy Azure to development
./deploy-azure.sh dev

# Deploy Hetzner to production
./deploy-hetzner.sh prod
```

## Provider Configuration File

The **[providers.conf](providers.conf)** file structure:

```ini
[provider_name]
enabled=true/false          # Turn provider on/off
region/location=value       # Geographic region
token/id=value             # Authentication credentials
ssh_public_key_path=path   # SSH key for server access
module_path=./path         # Network module location
compute_module_path=./path # Compute module location
```

## Available Commands

### Adding Providers
```bash
./add-provider.sh <provider-name>
```

### Deployment Scripts (Auto-generated)
```bash
./deploy-aws.sh [dev|prod]
./deploy-azure.sh [dev|prod]
./deploy-hetzner.sh [dev|prod]
```

### Standard Terraform Commands
```bash
terraform init          # Initialize Terraform
terraform plan          # Preview changes
terraform apply         # Apply configuration
terraform destroy       # Destroy resources
terraform workspace list # List all workspaces
```

## Examples

### Example 1: Add Azure Provider

```bash
# Step 1: Add Azure
./add-provider.sh azure

# Step 2: Configure in providers.conf
# Edit [azure] section with your subscription ID

# Step 3: Initialize Terraform
terraform init

# Step 4: Deploy to development
./deploy-azure.sh dev
```

### Example 2: Add Server to Existing Provider

Create a new `.tfvars` file:

```bash
cat > myserver.tfvars << EOF
cloud_provider = "aws"
env_name       = "dev"
server_name    = "my-aws-server"
EOF

# Deploy
terraform workspace new myserver
terraform apply -var-file="myserver.tfvars"
```

### Example 3: Multi-Provider Setup

```bash
# Add multiple providers
./add-provider.sh azure
./add-provider.sh hetzner

# Configure both in providers.conf

# Deploy to different providers
./deploy-azure.sh dev
./deploy-hetzner.sh prod
```

## What Gets Created

When you run **[add-provider.sh](add-provider.sh)**:

### Files Created
- `modules/network-<provider>/` - Network security resources
- `modules/compute-<provider>/` - Compute instance resources
- `<provider>-dev.tfvars` - Development variables
- `<provider>-prod.tfvars` - Production variables
- `deploy-<provider>.sh` - Deployment script
- `README-<provider>.md` - Provider-specific documentation

### Files Updated
- `providers.conf` - Adds provider configuration
- `provider.tf` - Adds provider block
- `variables.tf` - Adds provider-specific variables

## Provider Switching

The **[main.tf](main.tf)** automatically switches modules based on `cloud_provider` variable:

```hcl
module "compute" {
  source = "./modules/compute-${var.cloud_provider}"
  # ...
}
```

This means you can deploy the same infrastructure to different providers just by changing one variable.

## Security Notes

- **Never commit** sensitive credentials to version control
- Use environment variables for tokens and IDs
- Mark sensitive variables with `sensitive = true`
- Consider using Terraform Cloud/AWS Secrets Manager for credentials

## Troubleshooting

### Provider Not Found
```bash
terraform init
```

### Workspace Issues
```bash
terraform workspace list
terraform workspace select <workspace>
```

### Permission Denied on Scripts
```bash
chmod +x add-provider.sh
chmod +x deploy-*.sh
```

### State Lock Issues
```bash
terraform force-unlock <LOCK_ID>
```

## Best Practices

1. **Test First**: Always deploy to dev environment first
2. **Use Workspaces**: Separate workspaces for each environment
3. **Backup State**: Your S3 state is versioned - use it!
4. **Document Changes**: Update README files when modifying modules
5. **Monitor Costs**: Set up billing alerts for each provider

## Support

Each provider gets its own **README-<provider>.md** file with:
- Provider-specific setup instructions
- Region/location options
- Credential requirements
- Example configurations

## Summary

This system makes multi-cloud infrastructure management simple:

- **One command** to add any provider
- **One file** for all provider configurations
- **One place** to enable/disable providers
- **Automated** script and file generation

Just edit **[providers.conf](providers.conf)** and run **[add-provider.sh](add-provider.sh)** - everything else is handled automatically.

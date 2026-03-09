# Terraform Workspaces Guide

This project now uses Terraform workspaces for environment isolation. Each workspace has its own state file, allowing you to manage multiple environments simultaneously.

## What are Terraform Workspaces?

Terraform workspaces allow you to:
- Create isolated environments (dev, prod, test, etc.) from the same code
- Each workspace has its own state file
- Scale easily by adding new workspaces without code changes
- Manage resources independently per workspace

## Workspace Commands

### List Workspaces
```bash
terraform workspace list
```

### Create a New Workspace
```bash
terraform workspace new dev
terraform workspace new prod
terraform workspace new test
terraform workspace new staging  # Add more as needed
```

### Switch to a Workspace
```bash
terraform workspace select prod
```

### Show Current Workspace
```bash
terraform workspace show
```

### Delete a Workspace
```bash
terraform workspace delete staging
```

## Workflow

### 1. Initialize Workspaces
```bash
# Create all your workspaces
terraform workspace new dev
terraform workspace new prod
terraform workspace new test
```

### 2. Deploy to Each Workspace
```bash
# Deploy to dev
terraform workspace select dev
terraform init
terraform apply

# Deploy to prod
terraform workspace select prod
terraform init
terraform apply

# Deploy to test
terraform workspace select test
terraform init
terraform apply
```

### 3. Manage Each Environment Independently
```bash
# Add a server to dev only
terraform workspace select dev
terraform plan
terraform apply

# Scale prod with different instance type
terraform workspace select prod
terraform apply -var="instance_type=t3.large"
```

## Environment-Specific Variables

### Option 1: Workspace-Specific tfvars Files
```
terraform/
├── dev.tfvars
├── prod.tfvars
├── test.tfvars
└── staging.tfvars
```

```bash
terraform workspace select dev
terraform apply -var-file=dev.tfvars

terraform workspace select prod
terraform apply -var-file=prod.tfvars
```

### Option 2: Use terraform.tfvars per workspace
Terraform automatically loads `terraform.tfvars` from the current directory.

### Option 3: Pass Variables via CLI
```bash
terraform workspace select prod
terraform apply \
  -var="instance_type=t3.large" \
  -var="server_name=prod-api-server"
```

## Automatic Workspace Configuration

Variables now have smart defaults based on the workspace:

```hcl
# Automatically uses workspace name
env_name = terraform.workspace

# Automatically creates server-<workspace>
server_name = "server-${terraform.workspace}"
```

## State Files

Each workspace has its own state file in S3:

```
s3://aayushmaan-terraform/
├── infrastructure/terraform.tfstate        # Default workspace
├── env:/dev/terraform.tfstate             # Dev workspace state
└── env:/prod/terraform.tfstate            # Prod workspace state
```

Note: State files are separated by workspace to prevent conflicts.

## Scalability

### Adding New Environments

Simply create a new workspace - no code changes needed:

```bash
terraform workspace new staging
terraform apply
```

### Removing Environments

Destroy resources and delete the workspace:

```bash
terraform workspace select staging
terraform destroy
terraform workspace delete staging
```

## Example Workflow

### Initial Setup
```bash
# Create all workspaces
terraform workspace new dev
terraform workspace new prod
terraform workspace new test
```

### Deploy All Environments
```bash
# Deploy dev
terraform workspace select dev
terraform init
terraform apply -auto-approve

# Deploy prod
terraform workspace select prod
terraform init
terraform apply -var="instance_type=t3.medium" -auto-approve

# Deploy test
terraform workspace select test
terraform init
terraform apply -auto-approve
```

### Get Server Information
```bash
# Get prod server IP
terraform workspace select prod
terraform output public_ip

# Get all outputs
terraform output
```

### Update Specific Environment
```bash
# Scale up prod only
terraform workspace select prod
terraform apply -var="instance_type=t3.large"

# This won't affect dev or test environments
```

## Dynamic AMI Lookup

The infrastructure now automatically fetches the latest Ubuntu 24.04 LTS AMI:

- No need to hardcode AMI IDs
- Automatically uses the most recent AMI
- Can still specify a custom AMI if needed via `ami_id` variable

```bash
# Use default (latest Ubuntu AMI)
terraform apply

# Use specific AMI
terraform apply -var="ami_id=ami-0123456789abcdef0"
```

## Common Patterns

### Development Workspace
```bash
terraform workspace select dev
terraform apply -var="instance_type=t3.micro"
```

### Production Workspace
```bash
terraform workspace select prod
terraform apply -var="instance_type=t3.large"
```

### Workspace with Custom Server Name
```bash
terraform workspace select prod
terraform apply -var="server_name=production-api"
```

## Troubleshooting

### Workspace Not Found
```bash
# List available workspaces
terraform workspace list

# Create if needed
terraform workspace new dev
```

### State Locked
```bash
# Remove the lock file
rm .terraform.lock.hcl

# Or use Terraform Cloud/Enterprise for better locking
```

### Wrong Workspace Selected
```bash
# Always verify current workspace before applying
terraform workspace show

# Switch to correct workspace
terraform workspace select prod
```

## Best Practices

1. **Always verify workspace** before running `terraform apply`
2. **Use descriptive workspace names** (dev, staging, prod, etc.)
3. **Keep workspace state separate** - don't switch workspaces during operations
4. **Document workspace usage** in your team
5. **Use CI/CD with workspaces** - GitHub Actions can select workspace based on branch

## CI/CD Integration Example

```yaml
- name: Terraform Apply to Dev
  run: |
    terraform workspace select dev
    terraform apply -auto-approve

- name: Terraform Apply to Prod
  if: github.ref == 'refs/heads/main'
  run: |
    terraform workspace select prod
    terraform apply -auto-approve
```

# Terraform Environments

## Structure
- `main.tf` - Infrastructure configuration
- `variables.tf` - Variable declarations
- `terraform.tfvars` - Default (dev) environment values
- `prod.tfvars` - Production environment values
- `test.tfvars` - Test environment values

## Usage

### Development (default)
```bash
terraform init
terraform plan
terraform apply
```

### Production
```bash
terraform apply -var-file=prod.tfvars
```

### Test
```bash
terraform apply -var-file=test.tfvars
```

## Outputs

After applying, Terraform will display the server information:

```
Outputs:

instance_id = "i-0123456789abcdef0"
public_ip = "54.123.45.67"
private_ip = "10.0.1.123"
server_name = "test-prod"
env_name = "prod"
```

You can also view outputs anytime:
```bash
terraform output
```

Or specific outputs:
```bash
terraform output public_ip
terraform output instance_id
```

## Environment-Specific Changes

To deploy to a different environment:
1. Update the `.tfvars` file for that environment
2. Run terraform with the `-var-file` flag

For example, to change the server name for production, edit `prod.tfvars`:
```hcl
server_name = "my-prod-server"
```

## Important Notes

### Single Environment Deployment
This Terraform configuration is designed to deploy **one environment at a time**:
- Running `terraform apply` deploys the environment specified in the `.tfvars` file
- Each deployment replaces the previous one (same state file)
- To deploy a different environment, re-run with a different `-var-file`

If you need multiple environments running simultaneously, you would need to:
1. Use Terraform workspaces (`terraform workspace new prod`)
2. Or create separate state files with different backend keys

### State Management
All deployments share the same S3 state file:
- Bucket: `aayushmaan-terraform`
- Key: `infrastructure/terraform.tfstate`

This is intentional for this sample project to keep things simple.

## Destroy Resources
```bash
terraform destroy -var-file=prod.tfvars
```

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

## Environment-Specific Changes

To deploy to a different environment:
1. Update the `.tfvars` file for that environment
2. Run terraform with the `-var-file` flag

For example, to change the server name for production, edit `prod.tfvars`:
```hcl
server_name = "my-prod-server"
```

## Destroy Resources
```bash
terraform destroy -var-file=prod.tfvars
```

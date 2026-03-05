# IaC Sample Project

A sample project demonstrating Infrastructure as Code (IaC) with a simple Python application, Docker containerization, and Terraform infrastructure on AWS.

## Project Structure

```
IAAC/
├── app.py                    # Simple Flask API
├── Dockerfile                # Container definition
├── requirements.txt          # Python dependencies
├── docker-compose.yml        # Local development orchestration
├── .env                      # Environment variables (local)
├── .gitignore                # Git ignore rules
├── README.md                 # This file
└── terraform/                # Infrastructure as Code
    ├── backend.tf            # Terraform backend configuration (S3)
    ├── main.tf               # Infrastructure configuration
    ├── provider.tf           # AWS provider
    ├── variables.tf          # Variable declarations
    ├── terraform.tfvars      # Default (dev) environment values
    ├── prod.tfvars           # Production environment values
    ├── test.tfvars           # Test environment values
    ├── README.md             # Terraform-specific documentation
    └── modules/
        ├── compute/
        │   ├── main.tf       # EC2 instance resource
        │   └── variables.tf  # Compute module variables
        └── network/
            ├── main.tf       # Security group resource
            └── variables.tf  # Network module variables
```

## Application

### Overview
A simple Flask API that returns "Hola Amigo" along with the current environment mode.

### API Endpoint
```
GET /
```

**Response:**
```json
{
  "message": "Hola Amigo",
  "mode": "dev"
}
```

### Local Development with Docker Compose

```bash
# Build and start all services
docker-compose up

# Start specific environment
MODE=prod docker-compose up
MODE=dev docker-compose up
MODE=test docker-compose up
```

### Services
| Service | Description | Port |
|---------|-------------|------|
| app | Python Flask API | 5000 |
| redis | Redis cache | 6379 |
| postgres | PostgreSQL database | 5432 |

## Terraform Infrastructure

### Overview
Terraform configuration for deploying AWS infrastructure across multiple environments (dev, test, prod).

### Infrastructure Components
- **VPC Security Group**: Allows SSH (22), HTTP (80), and HTTPS (443) traffic
- **EC2 Instance**: Ubuntu 24.04 LTS with 60GB GP3 storage

### AWS Credentials Setup

Before running Terraform, you need to configure AWS credentials.

#### Option 1: AWS CLI (Recommended)
```powershell
aws configure
```

#### Option 2: PowerShell Environment Variables
```powershell
[System.Environment]::SetEnvironmentVariable('AWS_ACCESS_KEY_ID', 'your-access-key-id', 'User')
[System.Environment]::SetEnvironmentVariable('AWS_SECRET_ACCESS_KEY', 'your-secret-access-key', 'User')
[System.Environment]::SetEnvironmentVariable('AWS_DEFAULT_REGION', 'us-east-1', 'User')
```

#### Option 3: AWS Credentials File
Create `%USERPROFILE%\.aws\credentials`:
```ini
[default]
aws_access_key_id = your-access-key-id
aws_secret_access_key = your-secret-access-key
```

Create `%USERPROFILE%\.aws\config`:
```ini
[default]
region = us-east-1
```

### Terraform Workflow

```bash
# Navigate to terraform directory
cd terraform

# Initialize Terraform (downloads providers and initializes modules)
terraform init

# Plan infrastructure changes
terraform plan

# Apply with default (dev) environment
terraform apply

# Apply with specific environment
terraform apply -var-file=prod.tfvars
terraform apply -var-file=test.tfvars

# Destroy infrastructure
terraform destroy -var-file=prod.tfvars
```

### Backend Configuration

Terraform state is stored in an S3 bucket with encryption enabled:
- **Bucket**: `aayushmaan-terraform`
- **Key**: `infrastructure/terraform.tfstate`
- **Region**: `us-east-1`
- **Encryption**: Enabled

**Note:** The S3 bucket must be created manually before running `terraform init`.

### Environment Configuration

Each environment uses a `.tfvars` file to define its values:

**Development (`terraform.tfvars`):**
```hcl
env_name    = "dev"
server_name = "test-dev"
```

**Production (`prod.tfvars`):**
```hcl
env_name    = "prod"
server_name = "test-prod"
```

**Test (`test.tfvars`):**
```hcl
env_name    = "test"
server_name = "test-test"
```

### Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `env_name` | Environment name for tagging | - |
| `server_name` | Name tag for EC2 instance | - |
| `instance_type` | EC2 instance type | `t3.micro` |
| `ami_id` | Ubuntu 24.04 LTS AMI (us-east-1) | `ami-0e2c8caa4b6378d8c` |
| `key_name` | AWS key pair name | `aayush-test` |

### Terraform Modules

**Network Module** (`modules/network/`)
- Creates a security group with common ports open
- Outputs security group ID

**Compute Module** (`modules/compute/`)
- Creates EC2 instance with specified configuration
- Uses security group from network module

### Module Structure

The `modules.json` file shows the initialized modules:
```json
{
  "Modules": [
    { "Key": "", "Source": "", "Dir": "." },
    { "Key": "compute", "Source": "./modules/compute", "Dir": "modules/compute" },
    { "Key": "network", "Source": "./modules/network", "Dir": "modules/network" }
  ]
}
```

## Environment Variables

### Docker Compose (.env)
```bash
# Application
MODE=dev
APP_PORT=5000

# Redis
REDIS_PORT=6379
REDIS_PASSWORD=myredispassword

# PostgreSQL
POSTGRES_PORT=5432
POSTGRES_USER=admin
POSTGRES_PASSWORD=admin
POSTGRES_DB=testdb
```

### Application Environment Variables
The Python app has access to:
- `MODE` - Current environment mode
- `REDIS_HOST`, `REDIS_PORT`, `REDIS_PASSWORD` - Redis connection
- `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` - PostgreSQL connection

## Quick Start

### 1. Local Development
```bash
# Start the stack
docker-compose up

# Test the API
curl http://localhost:5000
```

### 2. Deploy to AWS

#### Prerequisites
- AWS account with appropriate permissions
- S3 bucket for Terraform state (`aayushmaan-terraform`)
- AWS credentials configured
- Terraform installed

#### Deployment Steps
```bash
# Set up AWS credentials (if not already done)
aws configure

# Navigate to terraform directory
cd terraform

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply infrastructure
terraform apply -var-file=prod.tfvars
```

## Setup Instructions

### Create S3 Bucket for Terraform State
Before running Terraform, create the S3 bucket:
```bash
aws s3 mb s3://aayushmaan-terraform --region us-east-1
aws s3api put-bucket-versioning --bucket aayushmaan-terraform --versioning-configuration Status=Enabled
```

### Install Terraform
- Download from https://developer.hashicorp.com/terraform/install
- Or use `winget install HashiCorp.Terraform`
- Or use `choco install terraform`

## Notes

- The `modules/envs/` folder was removed in favor of using `.tfvars` files for environment management
- This follows Terraform best practices for multi-environment setups
- `.gitignore` excludes sensitive `.env` files and `.tfvars` files
- AWS credentials should never be committed to version control
- The S3 backend requires the bucket to exist before initialization
- Use `use_lockfile` instead of deprecated `dynamodb_table` for state locking

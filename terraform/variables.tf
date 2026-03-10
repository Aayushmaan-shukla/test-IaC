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

# Environment name - can be overridden via .tfvars or CLI
variable "env_name" {
  type        = string
  default     = ""  # Empty default - will use workspace name
  description = "Environment name (defaults to Terraform workspace name if not specified)"
}

# Server name - can be overridden via .tfvars or CLI
variable "server_name" {
  type        = string
  default     = ""  # Empty default - will use workspace-based naming
  description = "Server name tag (defaults to server-<workspace> if not specified)"
}

variable "instance_type" {
  type        = string
  default     = "t3.micro"
  description = "EC2 instance type"
}

# AMI ID is now fetched dynamically from data source, not hardcoded
# Kept for backward compatibility but will be overridden by data source
variable "ami_id" {
  type        = string
  default     = ""
  description = "AMI ID (optional - uses latest Ubuntu AMI if not specified)"
  nullable    = true
}

variable "key_name" {
  type        = string
  default     = "aayush-test"
  description = "AWS key pair name for SSH access"
}

# Azure-specific variables
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

# Hetzner-specific variables
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

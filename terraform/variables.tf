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

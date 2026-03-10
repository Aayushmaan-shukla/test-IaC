# Use dynamic AMI from data source or fallback to variable
locals {
  ami_id      = var.cloud_provider == "aws" ? (var.ami_id != "" ? var.ami_id : data.aws_ami.ubuntu.id) : ""
  env_name    = var.env_name != "" ? var.env_name : terraform.workspace
  server_name = var.server_name != "" ? var.server_name : "server-${terraform.workspace}"
}

# Initialize the network based on provider selection
module "network" {
  source   = var.cloud_provider == "aws" ? "./modules/network" : "./modules/network-${var.cloud_provider}"
  env_name = local.env_name
}

# Create the Server based on provider selection
module "compute" {
  source            = var.cloud_provider == "aws" ? "./modules/compute" : "./modules/compute-${var.cloud_provider}"
  env_name          = local.env_name
  server_name       = local.server_name
  instance_type     = var.instance_type
  ami_id            = local.ami_id
  key_name          = var.key_name
  security_group_id = module.network.sg_id

  # Azure-specific variables (passed but may not be used by AWS)
  azure_location        = var.azure_location
  azure_resource_group  = var.azure_resource_group
  azure_ssh_public_key  = var.azure_ssh_public_key

  # Hetzner-specific variables
  hetzner_location       = var.hetzner_location
  hetzner_token          = var.hetzner_token
  hetzner_ssh_public_key = var.hetzner_ssh_public_key
}

# Outputs
output "instance_id" {
  value = module.compute.instance_id
}

output "public_ip" {
  value = module.compute.public_ip
}

output "private_ip" {
  value = module.compute.private_ip
}

output "server_name" {
  value = local.server_name
}

output "env_name" {
  value = local.env_name
}

output "workspace" {
  value = terraform.workspace
}

output "ami_id" {
  value = local.ami_id
  description = "The AMI ID used for the instance"
}

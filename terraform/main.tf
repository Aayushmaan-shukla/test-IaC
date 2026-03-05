# Initialize the network (Security Groups)
module "network" {
  source   = "./modules/network"
  env_name = var.env_name
}

# Create the Server
module "compute" {
  source            = "./modules/compute"
  env_name          = var.env_name
  server_name       = var.server_name
  instance_type     = var.instance_type
  ami_id            = var.ami_id
  key_name          = var.key_name
  security_group_id = module.network.sg_id
}
variable "env_name" {}

variable "server_name" {}

variable "instance_type" {
  default = "t3.micro"
}

variable "ami_id" {
  # Ubuntu 24.04 LTS AMI for us-east-1
  default = "ami-0e2c8caa4b6378d8c"
}

variable "key_name" {
  default = "aayush-test"
}
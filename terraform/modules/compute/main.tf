resource "aws_instance" "server" {
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = [var.security_group_id]

  root_block_device {
    volume_size = 60
    volume_type = "gp3"
  }

  tags = {
    Name = var.server_name
    Env  = var.env_name
  }
}
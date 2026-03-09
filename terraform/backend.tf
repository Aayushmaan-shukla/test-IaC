terraform {
  backend "s3" {
    bucket         = "aayushmaan-terraform"
    key            = "infrastructure/terraform.tfstate"
    region         = "us-east-1"
    use_lockfile   = true
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

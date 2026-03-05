terraform {
  backend "s3" {
    bucket         = "aayushmaan-terraform"
    key            = "infrastructure/terraform.tfstate"
    region         = "us-east-1" # Virginia
    use_lockfile   = true
    encrypt        = true
  }
}
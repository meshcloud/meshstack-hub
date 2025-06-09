provider "aws" {
  region = "eu-central-1"

  assume_role {
    role_arn     = var.assume_role_arn
    session_name = "deploy-building-block"
  }
}
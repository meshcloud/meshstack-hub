provider "aws" {
  region = "eu-central-1"

  assume_role {
    role_arn     = "arn:${var.aws_partition}:iam::${var.account_id}:role/${var.assume_role_name}"
    session_name = "deploy-budget-alert"
  }
}
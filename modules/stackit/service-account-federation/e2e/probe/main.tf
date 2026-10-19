terraform {
  required_version = ">= 1.11.0"

  required_providers {
    stackit = {
      source  = "stackitcloud/stackit"
      version = ">= 0.98.0, < 1.0.0"
    }
  }
}

# Authenticates through the STACKIT_* environment the definition sets, which makes the run act as
# the federated service account.
provider "stackit" {}

variable "project_id" {
  type        = string
  description = "STACKIT project of the target tenant."
}

data "stackit_resourcemanager_project" "this" {
  project_id = var.project_id
}

output "project_name" {
  value       = data.stackit_resourcemanager_project.this.name
  description = "Name of the project the federated service account read."
}

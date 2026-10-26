terraform {
  required_version = ">= 1.12.0"

  required_providers {
    stackit = {
      source  = "stackitcloud/stackit"
      version = ">= 0.82.0, < 1.0.0"
    }
  }
}

provider "stackit" {
  default_region = "eu01"
}

variable "test_context" {
  type = object({
    run_id = string

    fixtures = object({
      stackit = object({
        secrets_manager_instance_id = string
        ske_platform = object({
          project_id = string
        })
      })
    })
  })
  nullable = false
}

resource "stackit_secretsmanager_user" "reader" {
  project_id    = var.test_context.fixtures.stackit.ske_platform.project_id
  instance_id   = var.test_context.fixtures.stackit.secrets_manager_instance_id
  description   = "${var.test_context.run_id} run-controller reader"
  write_enabled = false
}

output "username" {
  value = stackit_secretsmanager_user.reader.username
}

output "password" {
  value     = stackit_secretsmanager_user.reader.password
  sensitive = true
}

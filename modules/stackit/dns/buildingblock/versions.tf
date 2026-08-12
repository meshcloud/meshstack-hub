terraform {
  required_version = ">= 1.11.0"

  required_providers {
    stackit = {
      source = "stackitcloud/stackit"
      # 0.110.0 is the version this module was written against. It carries the DNS zone data source
      # with lookup by `dns_name` and the `iam` experiment that gates
      # `stackit_authorization_project_role_assignment`.
      version = ">= 0.110.0"
    }
  }
}

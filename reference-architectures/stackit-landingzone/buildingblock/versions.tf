terraform {
  required_version = ">= 1.12.0" # const variables require OpenTofu >= 1.12 / Terraform >= 1.15

  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.24.0"
    }
    stackit = {
      source = "stackitcloud/stackit"
      # 0.110.0 is what the nested `stackit/ske/backplane` and `stackit/dns` modules demand, and this
      # root now composes them behind the kubernetes option. Declaring the same floor keeps the
      # effective constraint visible here instead of only in a child module.
      version = ">= 0.110.0"
    }
  }
}

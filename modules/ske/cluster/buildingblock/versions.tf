terraform {
  required_version = ">= 1.11.0"

  required_providers {
    stackit = {
      source = "stackitcloud/stackit"
      # 0.83 is the first release carrying the SKE cluster + kubeconfig resources this module needs.
      version = ">= 0.83.0, < 1.0.0"
    }
  }
}

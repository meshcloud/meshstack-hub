provider "stackit" {
  default_region        = var.stackit_region
  enable_beta_resources = true
  experiments           = ["iam"]
}

locals {
  # meshStack writes kubeconfig.yaml from the optional FILE input. Without it, the providers read the
  # committed mock and the ACME solver stays disabled.
  kubeconfig_given = fileexists("${path.module}/kubeconfig.yaml")
  kubeconfig_path  = local.kubeconfig_given ? "${path.module}/kubeconfig.yaml" : "${path.module}/kubeconfig-mock.yaml"
}

provider "kubernetes" {
  config_path = local.kubeconfig_path
}

provider "helm" {
  kubernetes = {
    config_path = local.kubeconfig_path
  }
}

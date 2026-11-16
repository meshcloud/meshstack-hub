provider "stackit" {
  default_region        = var.stackit_region
  enable_beta_resources = true
  experiments           = ["iam"]
}

locals {
  kubeconfig_given = fileexists("${path.module}/kubeconfig.yaml")
}

provider "kubernetes" {
  config_path = local.kubeconfig_given ? "${path.module}/kubeconfig.yaml" : null
  # validate and plan run without the kubeconfig meshStack writes at run time.
  host = local.kubeconfig_given ? null : "https://example.invalid"
}

provider "helm" {
  kubernetes = {
    config_path = local.kubeconfig_given ? "${path.module}/kubeconfig.yaml" : null
    host        = local.kubeconfig_given ? null : "https://example.invalid"
  }
}

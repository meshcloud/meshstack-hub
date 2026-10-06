locals {
  # meshStack writes kubeconfig.yaml from a static FILE input at run time. The committed mock lets
  # the module validate without it, and a precondition stops an apply against the mock.
  kubeconfig_path = fileexists("${path.module}/kubeconfig.yaml") ? "${path.module}/kubeconfig.yaml" : "${path.module}/kubeconfig-mock.yaml"
}

provider "kubernetes" {
  config_path = local.kubeconfig_path
}

provider "helm" {
  kubernetes = {
    config_path = local.kubeconfig_path
  }
}

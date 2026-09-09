locals {
  # meshStack injects kubeconfig.yaml as a static FILE input at run time. `try` falls back to the
  # committed mock so the module still validates without it, and the precondition in main.tf is
  # what stops an apply against the mock.
  kubeconfig = try(
    yamldecode(file("${path.module}/kubeconfig.yaml")),
    yamldecode(file("${path.module}/kubeconfig-mock.yaml"))
  )
  kubeconfig_cluster = one(local.kubeconfig["clusters"])["cluster"]
  kubeconfig_user    = one(local.kubeconfig["users"])["user"]
}

provider "helm" {
  kubernetes {
    host                   = local.kubeconfig_cluster["server"]
    cluster_ca_certificate = base64decode(local.kubeconfig_cluster["certificate-authority-data"])

    # Service account token auth (produced by the manifest backplane).
    # Falls back to client certificate auth when running with the mock kubeconfig.
    token              = try(local.kubeconfig_user["token"], null)
    client_certificate = try(base64decode(local.kubeconfig_user["client-certificate-data"]), null)
    client_key         = try(base64decode(local.kubeconfig_user["client-key-data"]), null)
  }
}

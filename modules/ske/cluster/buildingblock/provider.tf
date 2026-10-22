# Credentials come from the STACKIT_* environment inputs meshStack sets for workload identity federation.
provider "stackit" {
  default_region = var.stackit_region
  experiments    = ["ske"]
}

provider "kubernetes" {
  host                   = one(local.ske_kubeconfig.clusters).cluster.server
  cluster_ca_certificate = base64decode(one(local.ske_kubeconfig.clusters).cluster["certificate-authority-data"])
  client_certificate     = base64decode(one(local.ske_kubeconfig.users).user["client-certificate-data"])
  client_key             = base64decode(one(local.ske_kubeconfig.users).user["client-key-data"])
}

# The cluster only exists in hub mode, so its provider is configured here rather than in the root.
# Foundation mode then never installs the kubernetes provider at all.
#
# A module holding a provider block may not take `count`, `for_each` or `depends_on` — so keep those
# off the `module "definition"` block in the root.
provider "kubernetes" {
  host                   = local.ske_kubeconfig["clusters"][0]["cluster"]["server"]
  cluster_ca_certificate = base64decode(local.ske_kubeconfig["clusters"][0]["cluster"]["certificate-authority-data"])
  client_certificate     = base64decode(local.ske_kubeconfig["users"][0]["user"]["client-certificate-data"])
  client_key             = base64decode(local.ske_kubeconfig["users"][0]["user"]["client-key-data"])
}

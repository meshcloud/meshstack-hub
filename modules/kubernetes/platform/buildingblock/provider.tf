# Callers that drive this module from Terragrunt usually replace this file with a generated
# `provider.tf` of their own. In that case the three credential variables stay unset and the
# generated block carries the credentials instead.
provider "kubernetes" {
  host                   = var.kube_host
  cluster_ca_certificate = var.cluster_ca_certificate
  client_certificate     = var.client_certificate
  client_key             = var.client_key
}

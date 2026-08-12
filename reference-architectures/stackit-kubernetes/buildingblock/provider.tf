# The ingress module is installed only when `expose` is not `none`, so it is called with `count`.
# A module that carries its own provider configuration cannot be called with `count`, which is why
# this root configures the cluster credentials and passes both providers down.
provider "kubernetes" {
  host                   = module.cluster.provider_config.host
  cluster_ca_certificate = module.cluster.provider_config.cluster_ca_certificate
  client_certificate     = module.cluster.provider_config.client_certificate
  client_key             = module.cluster.provider_config.client_key
}

provider "helm" {
  kubernetes = {
    host                   = module.cluster.provider_config.host
    cluster_ca_certificate = module.cluster.provider_config.cluster_ca_certificate
    client_certificate     = module.cluster.provider_config.client_certificate
    client_key             = module.cluster.provider_config.client_key
  }
}

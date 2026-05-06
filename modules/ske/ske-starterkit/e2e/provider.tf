provider "kubernetes" {
  host                   = jsondecode(var.ske_kubeconfig)["clusters"][0]["cluster"]["server"]
  cluster_ca_certificate = base64decode(jsondecode(var.ske_kubeconfig)["clusters"][0]["cluster"]["certificate-authority-data"])
  client_certificate     = base64decode(jsondecode(var.ske_kubeconfig)["users"][0]["user"]["client-certificate-data"])
  client_key             = base64decode(jsondecode(var.ske_kubeconfig)["users"][0]["user"]["client-key-data"])
}
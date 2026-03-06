terraform {
  required_providers {
    harbor = {
      source  = "goharbor/harbor"
      version = "3.11.3"
    }
  }
}

provider "harbor" {
  url      = var.harbor_endpoint
  username = var.harbor_username
  password = var.harbor_password
}

provider "kubernetes" {
  host           = "https://${var.cluster_endpoint}"
  config_path    = var.cluster_config_path
  config_context = var.cluster_config_context
}

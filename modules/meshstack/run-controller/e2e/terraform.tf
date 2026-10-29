terraform {
  required_version = ">= 1.12.0"

  required_providers {
    meshstack = {
      source = "meshcloud/meshstack"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 3.0.0, < 4.0.0"
    }
    github = {
      source = "integrations/github"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.12, < 1.0.0"
    }
  }
}

provider "kubernetes" {
  host                   = local.ske_kubeconfig["clusters"][0]["cluster"]["server"]
  cluster_ca_certificate = base64decode(local.ske_kubeconfig["clusters"][0]["cluster"]["certificate-authority-data"])
  client_certificate     = base64decode(local.ske_kubeconfig["users"][0]["user"]["client-certificate-data"])
  client_key             = base64decode(local.ske_kubeconfig["users"][0]["user"]["client-key-data"])
}

provider "github" {
  owner = var.test_context.fixtures.github.owner

  app_auth {
    id              = var.github_app_id
    installation_id = var.github_app_installation_id
    pem_file        = var.github_app_private_key
  }
}

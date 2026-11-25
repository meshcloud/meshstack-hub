terraform {
  required_version = ">= 1.12.0"

  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.29.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 3.0.0, < 4.0.0"
    }
    github = {
      source  = "integrations/github"
      version = ">= 6.0.0, < 7.0.0"
    }
    azuredevops = {
      source  = "microsoft/azuredevops"
      version = ">= 1.1.1, < 2.0.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = ">= 5.12.0, < 6.0.0"
    }
  }
}

provider "kubernetes" {
  host                   = local.ske_kubeconfig["clusters"][0]["cluster"]["server"]
  cluster_ca_certificate = base64decode(local.ske_kubeconfig["clusters"][0]["cluster"]["certificate-authority-data"])
  token                  = local.ske_kubeconfig["users"][0]["user"]["token"]
}

provider "vault" {
  address = local.secrets_manager_address
  # A Secrets Manager user may not create the child token the provider asks for by default.
  skip_child_token = true

  auth_login_userpass {
    username = var.secrets_manager_username
    password = var.secrets_manager_password
  }
}

provider "github" {
  owner = var.test_context.fixtures.github.owner

  app_auth {
    id              = var.github_app_id
    installation_id = var.github_app_installation_id
    pem_file        = var.github_app_private_key
  }
}

provider "azuredevops" {
  org_service_url       = "https://dev.azure.com/${var.test_context.fixtures.azuredevops.organization}"
  personal_access_token = var.azuredevops_personal_access_token
}

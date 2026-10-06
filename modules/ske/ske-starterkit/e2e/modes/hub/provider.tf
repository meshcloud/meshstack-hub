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

provider "stackit" {
  # Credentials come from the environment, WIF in CI.
  default_region = "eu01"
}

provider "vault" {
  address = local.secrets_manager_address
  # A Secrets Manager user may not create the child token the provider asks for by default.
  skip_child_token = true

  auth_login_userpass {
    username = stackit_secretsmanager_user.writer.username
    password = stackit_secretsmanager_user.writer.password
  }
}

provider "vault" {
  alias = "reader"

  address          = local.secrets_manager_address
  skip_child_token = true

  auth_login_userpass {
    username = stackit_secretsmanager_user.reader.username
    password = stackit_secretsmanager_user.reader.password
  }
}

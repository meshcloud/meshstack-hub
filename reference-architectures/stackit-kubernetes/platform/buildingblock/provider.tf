provider "stackit" {
  # Secrets Manager is a regional service. `secrets_manager_address` in main.tf is fixed to this region.
  default_region = "eu01"
}

# Logs in as the reader user this run creates. On the first run its password is unknown while
# planning, so the ephemeral reads open during the apply.
provider "vault" {
  address = local.secrets_manager_address
  # A Secrets Manager user may not create the child token the provider asks for by default.
  skip_child_token = true

  auth_login_userpass {
    username = stackit_secretsmanager_user.reader.username
    password = stackit_secretsmanager_user.reader.password
  }
}

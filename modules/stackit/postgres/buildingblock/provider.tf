provider "stackit" {
  # PostgreSQL Flex is a regional service.
  default_region = "eu01"
}

provider "vault" {
  address = var.output_to_vault == null ? null : var.output_to_vault.address
  # A Secrets Manager user may not create the child token the provider asks for by default.
  skip_child_token = true

  dynamic "auth_login_userpass" {
    for_each = var.output_to_vault[*]
    content {
      username = auth_login_userpass.value.username
      password = var.output_to_vault_password
    }
  }
}

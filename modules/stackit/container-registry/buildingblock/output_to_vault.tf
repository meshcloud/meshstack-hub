locals {
  write_to_vault = nonsensitive(var.output_to_vault != null)

  vault_data_json = {
    push = jsonencode({ username = local.push_robot_username, password = local.push_robot_password })
    pull = jsonencode({ username = local.pull_robot_username, password = local.pull_robot_password })
  }

  # The version must be a number, so the first 48 bits of the hash stand in for it.
  vault_secret_hash = { for robot, json in local.vault_data_json : robot => parseint(substr(nonsensitive(sha256(json)), 0, 12), 16) }
}

provider "vault" {
  address = var.output_to_vault == null ? null : var.output_to_vault.address
  # A Secrets Manager user may not create the child token the provider asks for by default.
  skip_child_token = true

  dynamic "auth_login_userpass" {
    for_each = var.output_to_vault[*]
    content {
      username = auth_login_userpass.value.username
      password = auth_login_userpass.value.password
    }
  }
}

resource "vault_kv_secret_v2" "push_robot" {
  lifecycle {
    enabled = local.write_to_vault && local.mint_robots
  }

  mount                = var.output_to_vault.mount
  name                 = "${var.output_to_vault.path}/push"
  data_json_wo         = local.vault_data_json.push
  data_json_wo_version = local.vault_secret_hash.push
}

resource "vault_kv_secret_v2" "pull_robot" {
  lifecycle {
    enabled = local.write_to_vault && local.mint_robots
  }

  mount                = var.output_to_vault.mount
  name                 = "${var.output_to_vault.path}/pull"
  data_json_wo         = local.vault_data_json.pull
  data_json_wo_version = local.vault_secret_hash.pull
}

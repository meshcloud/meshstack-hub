locals {
  # The instance resource does not expose the API URL. STACKIT serves all eu01 instances from this
  # endpoint and mounts each instance's KV engine at its instance ID.
  api_url  = "https://prod.sm.eu01.stackit.cloud"
  kv_mount = stackit_secretsmanager_instance.this.instance_id

  portal_instance_path = "https://portal.stackit.cloud/secrets-manager/instances/${stackit_secretsmanager_instance.this.instance_id}"
  instance_url         = "${local.portal_instance_path}/overview?project=${var.project_id}"
  users_url            = "${local.portal_instance_path}/users?project=${var.project_id}"
}

output "instance_id" {
  value       = stackit_secretsmanager_instance.this.instance_id
  description = "ID of the Secrets Manager instance."
}

output "instance_url" {
  value       = local.instance_url
  description = "STACKIT portal link to the Secrets Manager instance."
}

output "api_url" {
  value       = local.api_url
  description = "Vault-compatible API endpoint of the Secrets Manager."
}

output "kv_mount" {
  value       = local.kv_mount
  description = "Mount path of the instance's KV v2 secrets engine."
}

output "summary" {
  description = "Summary with connection details."
  value = templatefile("${path.module}/SUMMARY.md.tftpl", {
    instance_name = stackit_secretsmanager_instance.this.name
    instance_url  = local.instance_url
    users_url     = local.users_url
    api_url       = local.api_url
    kv_mount      = local.kv_mount
  })
}

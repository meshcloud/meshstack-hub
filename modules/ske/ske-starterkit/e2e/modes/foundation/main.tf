variable "test_context" {
  type = object({
    bbd_version_ref = object({
      uuid = string
    })
  })
  nullable = false
}

# Unused here: the root pipes one uniform surface to both modes.
variable "backplane_secrets" {
  type      = any
  sensitive = true
}

output "version_ref" {
  value = var.test_context.bbd_version_ref
}

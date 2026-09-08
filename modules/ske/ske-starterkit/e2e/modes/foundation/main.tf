# Foundation mode: the foundation already deployed the building block definition and passes the
# version ref of the release it deployed. Nothing is built here.
variable "test_context" {
  type = object({
    bbd_version_ref = object({
      uuid = string
    })
  })
  nullable = false
}

# Unused. The root pipes one uniform input surface to both modes; a foundation builds no backplane
# and has none of these.
variable "secrets" {
  type      = any
  sensitive = true
}

output "version_ref" {
  value = var.test_context.bbd_version_ref
}

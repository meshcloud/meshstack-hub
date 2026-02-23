locals {
  trust_configuration = var.identity_provider != "" ? {
    identity_provider = var.identity_provider
  } : null
}

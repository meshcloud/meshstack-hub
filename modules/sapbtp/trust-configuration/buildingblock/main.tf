resource "btp_subaccount_trust_configuration" "custom_idp" {
  count = local.trust_configuration != null ? 1 : 0

  subaccount_id     = var.subaccount_id
  identity_provider = local.trust_configuration.identity_provider
}

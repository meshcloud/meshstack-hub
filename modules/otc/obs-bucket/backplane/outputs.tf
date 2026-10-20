output "identity_provider_name" {
  value       = opentelekomcloud_identity_provider.building_block.name
  description = "Identity provider the building block's pre-run script exchanges its run token at."
}

output "group_name" {
  value       = opentelekomcloud_identity_group_v3.building_block.name
  description = "IAM group holding the building block's permissions."
}

output "identity_provider_name" {
  value       = local.identity_provider_name
  description = "Identity provider prerun.sh exchanges the run token at."
}

output "group_name" {
  value       = opentelekomcloud_identity_group_v3.building_block.name
  description = "IAM group holding the building block's permissions."
}

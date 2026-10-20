output "identity_provider_name" {
  value       = module.workload_identity.identity_provider_name
  description = "Identity provider the building block's pre-run script exchanges its run token at."
}

output "group_name" {
  value       = module.workload_identity.group_name
  description = "IAM group holding the building block's permissions."
}

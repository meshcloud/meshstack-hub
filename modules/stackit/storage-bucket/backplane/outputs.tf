output "project_id" {
  value       = var.project_id
  description = "STACKIT project ID for Object Storage bucket creation."
}

output "service_account_email" {
  value       = stackit_service_account.building_block.email
  description = "Email of the STACKIT service account used by the buildingblock provider via WIF."
}

output "admin_s3_access_key" {
  value       = stackit_objectstorage_credential.admin.access_key
  description = "S3 access key for the admin credentials group used to manage bucket policies."
  sensitive   = true
}

output "admin_s3_secret_access_key" {
  value       = stackit_objectstorage_credential.admin.secret_access_key
  description = "S3 secret access key for the admin credentials group used to manage bucket policies."
  sensitive   = true
}

output "admin_credentials_group_urn" {
  value       = stackit_objectstorage_credentials_group.admin.urn
  description = "URN of the admin credentials group used to manage bucket policies."
}

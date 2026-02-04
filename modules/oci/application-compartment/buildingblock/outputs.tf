output "compartment_id" {
  description = "OCID of the created application compartment"
  value       = oci_identity_compartment.application.id
}

output "compartment_name" {
  description = "Name of the created application compartment"
  value       = oci_identity_compartment.application.name
}

output "reader_group_id" {
  description = "OCID of the readers group"
  value       = oci_identity_group.readers.id
}

output "reader_group_name" {
  description = "Name of the readers group"
  value       = oci_identity_group.readers.name
}

output "user_group_id" {
  description = "OCID of the users group"
  value       = oci_identity_group.users.id
}

output "user_group_name" {
  description = "Name of the users group"
  value       = oci_identity_group.users.name
}

output "admin_group_id" {
  description = "OCID of the admins group"
  value       = oci_identity_group.admins.id
}

output "admin_group_name" {
  description = "Name of the admins group"
  value       = oci_identity_group.admins.name
}

output "policy_id" {
  description = "OCID of the access policy"
  value       = oci_identity_policy.application.id
}

output "console_url" {
  description = "OCI Console URL for direct access to the compartment"
  value       = "https://console.${var.region}.oraclecloud.com/?region=${var.region}&compartmentId=${oci_identity_compartment.application.id}"
}

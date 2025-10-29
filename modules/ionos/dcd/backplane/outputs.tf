output "service_user_id" {
  description = "ID of the IONOS service user"
  value       = ionoscloud_user.ionos_service_user.id
}

output "service_user_email" {
  description = "Email of the IONOS service user"
  value       = ionoscloud_user.ionos_service_user.email
}

output "dcd_managers_group_id" {
  description = "ID of the DCD managers group"
  value       = ionoscloud_group.dcd_managers.id
}

output "dcd_managers_group_name" {
  description = "Name of the DCD managers group"
  value       = ionoscloud_group.dcd_managers.name
}
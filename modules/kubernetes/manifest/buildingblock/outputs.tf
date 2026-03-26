output "release_name" {
  description = "Name of the deployed Helm release."
  value       = helm_release.this.name
}

output "release_status" {
  description = "Status of the Helm release."
  value       = helm_release.this.status
}

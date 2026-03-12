output "forgejo_organization" {
  value       = jsondecode(data.http.org_lookup.response_body).username
  description = "Default STACKIT Git organization for repository creation"
}

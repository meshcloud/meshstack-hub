output "github_environment_name" {
  description = "GitHub environment that holds the deployment credentials of this namespace."
  value       = github_repository_environment.this.environment
}

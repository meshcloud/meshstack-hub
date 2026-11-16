output "chart_version" {
  description = "Version of the installed chart."
  value       = var.release_on_destroy ? helm_release.released.version : helm_release.this.version
}

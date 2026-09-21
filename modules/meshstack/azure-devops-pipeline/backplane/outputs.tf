output "ref_name" {
  description = "Full git ref the pipeline runs on, for the building block definition's `ref_name`."
  value       = var.azuredevops_ref_name
  depends_on  = [azuredevops_git_repository_file.pipeline]
}

output "pipeline_yaml_path" {
  description = "Repository path the pipeline file was committed to."
  value       = var.azuredevops_pipeline_yaml_path
  depends_on  = [azuredevops_git_repository_file.pipeline]
}

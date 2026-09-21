resource "azuredevops_git_repository_file" "pipeline" {
  repository_id  = var.azuredevops_repository_id
  file           = var.azuredevops_pipeline_yaml_path
  branch         = var.azuredevops_ref_name
  content        = file("${path.module}/pipelines/azure-pipelines.yml")
  commit_message = "chore(meshstack): provision the ${var.azuredevops_pipeline_yaml_path} reference pipeline"

  overwrite_on_create = true
}

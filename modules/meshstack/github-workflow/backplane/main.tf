locals {
  workflow_templates = {
    (var.github_apply_workflow) = {
      source_path = "${path.module}/dotgithub/workflows/apply.yml"
      name        = "${var.workflow_name_prefix}-apply"
    }
    (var.github_destroy_workflow) = {
      source_path = "${path.module}/dotgithub/workflows/destroy.yml"
      name        = "${var.workflow_name_prefix}-destroy"
    }
    (var.github_apply_workflow_async) = {
      source_path = "${path.module}/dotgithub/workflows/apply-async.yml"
      name        = "${var.workflow_name_prefix}-apply-async"
    }
    (var.github_destroy_workflow_async) = {
      source_path = "${path.module}/dotgithub/workflows/destroy-async.yml"
      name        = "${var.workflow_name_prefix}-destroy-async"
    }
  }
}

resource "github_repository_file" "workflow" {
  for_each = local.workflow_templates

  repository          = var.github_repository_name
  branch              = var.github_branch
  file                = ".github/workflows/${each.key}"
  content             = templatefile(each.value.source_path, { workflow_name = each.value.name })
  commit_message      = "chore(meshstack): provision ${each.key} workflow template"
  overwrite_on_create = true
}

locals {
  buildingblock = "${path.module}/../buildingblock"

  # The workflow runs the playbook from `ansible-vm-hardening/`, so the two paths move together.
  files = merge(
    { ".github/workflows/ansible-vm-hardening.yml" = file("${local.buildingblock}/workflow.yml") },
    { for f in fileset("${local.buildingblock}/ansible", "**") : "ansible-vm-hardening/${f}" => file("${local.buildingblock}/ansible/${f}") },
  )
}

resource "github_repository_file" "this" {
  for_each = local.files

  repository          = var.github_repository_name
  branch              = var.github_branch
  file                = each.key
  content             = each.value
  commit_message      = "chore(meshstack): provision ${each.key} from meshstack-hub ansible/vm-hardening"
  overwrite_on_create = true
}

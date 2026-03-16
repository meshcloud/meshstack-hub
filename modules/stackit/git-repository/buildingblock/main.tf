locals {
  have_clone_addr = trimspace(var.clone_addr) != "" && var.clone_addr != "null"
}

resource "forgejo_repository" "repository" {
  owner          = var.forgejo_organization
  name           = var.name
  description    = var.description
  private        = var.private
  default_branch = var.default_branch
  auto_init      = !local.have_clone_addr

  # One-time clone (not an ongoing mirror)
  clone_addr = local.have_clone_addr ? var.clone_addr : null
  mirror     = false
}

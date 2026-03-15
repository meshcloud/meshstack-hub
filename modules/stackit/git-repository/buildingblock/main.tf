# ── Repository ─────────────────────────────────────────────────────────────────

resource "forgejo_repository" "repository" {
  owner          = var.forgejo_organization
  name           = var.name
  description    = var.description
  private        = var.private
  default_branch = var.default_branch
  auto_init      = var.clone_addr == ""

  # One-time clone (not an ongoing mirror)
  clone_addr = var.clone_addr != "" ? var.clone_addr : null
  mirror     = false
}

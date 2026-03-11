# wave 2 — depends on azure/postgresql
variable "hub" {
  type = object({
    git_ref = string
  })
}

module "postgresql" {
  source = "github.com/meshcloud/meshstack-hub//modules/azure/postgresql/buildingblock?ref=abc123"
  hub    = var.hub
}

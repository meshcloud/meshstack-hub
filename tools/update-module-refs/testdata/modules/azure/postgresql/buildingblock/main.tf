# wave 1 — depends on aws/budget
variable "hub" {
  type = object({
    git_ref = string
  })
}

module "budget" {
  source = "github.com/meshcloud/meshstack-hub//modules/aws/budget/buildingblock?ref=abc123"
  hub    = var.hub
}

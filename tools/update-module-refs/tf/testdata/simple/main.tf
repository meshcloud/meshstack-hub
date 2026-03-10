variable "hub" {
  type = object({
    git_ref = string
  })
}

module "github_repo_bbd" {
  source = "github.com/meshcloud/meshstack-hub//modules/github/repository?ref=main"

  hub = var.hub
}

module "backplane" {
  source = "./backplane"
}

resource "meshstack_building_block_definition" "test" {
  metadata = {
    owned_by_workspace = "test"
  }
}
module "postgresql_bbd" {
  source = "github.com/meshcloud/meshstack-hub//modules/azure/postgresql?ref=v1.0.0"
}


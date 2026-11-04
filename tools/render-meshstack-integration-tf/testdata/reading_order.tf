variable "hub" {
  type = object({ git_ref = string })
}

output "building_block_definition" {
  value = meshstack_building_block_definition.this.metadata.uuid
}

# The backplane needs the definition's identity federation.
module "backplane" {
  source = "./backplane"
}

resource "meshstack_building_block_definition" "this" {
  spec = {
    display_name = "Example"
  }
}

terraform {
  required_providers {
    meshstack = {
      source = "meshcloud/meshstack"
    }
  }
}

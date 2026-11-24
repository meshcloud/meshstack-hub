# Every block of the access definition, in whatever workspace it was ordered. The platform-operator
# scope needs MANAGED_BUILDINGBLOCK_LIST, which the backplane grants this run's API key.
data "meshstack_building_blocks" "access" {
  managed_by_definition_uuid = var.building_block_definition_uuid
}

locals {
  # A block without `expires_at` has not finished its first run, so nothing says when it expires yet.
  # `&&` short-circuits from OpenTofu 1.10 on, which the definition pins.
  expired = {
    for bb in data.meshstack_building_blocks.access.building_blocks : bb.metadata.uuid => {
      workspace    = bb.metadata.owned_by_workspace
      display_name = bb.spec.display_name
      expires_at   = jsondecode(bb.status.outputs["expires_at"].value)
    }
    if contains(keys(coalesce(bb.status.outputs, {})), "expires_at") && timecmp(plantimestamp(), jsondecode(bb.status.outputs["expires_at"].value)) > 0
  }
}

# One instance per expired block: creating it requests the delete. The block stays listed while its
# destroy run is going, and the existing instance then requests nothing more. Once meshStack has
# deleted the block, the instance goes out of state on the next run. A failed request taints the
# instance, so the next run tries again.
resource "terraform_data" "delete" {
  for_each = local.expired

  input = each.value

  provisioner "local-exec" {
    # curl and jq come from the flake in ./nix, so nothing is installed on the runner. The
    # MESHSTACK_* credentials reach the script through the run's environment, never through state.
    command = "nix shell ./nix#curl ./nix#jq --command bash ./delete-building-block.sh"
    environment = {
      BUILDING_BLOCK_UUID = each.key
    }
  }
}

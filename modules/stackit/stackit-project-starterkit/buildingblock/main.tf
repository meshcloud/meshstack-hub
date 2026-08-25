# This top level exists only to sequence two things: the starterkit itself, and the building block
# removing itself once the starterkit is done. Everything the starterkit creates lives in `./this`,
# so `depends_on = [module.this]` covers all of it — including whatever gets added there later,
# without anyone having to remember to extend a resource list here.

module "this" {
  source = "./this"

  creator              = var.creator
  workspace_identifier = var.workspace_identifier
  tags                 = var.tags

  name         = var.name
  landing_zone = var.landing_zone

  platform_ref      = var.platform_ref
  landing_zone_refs = var.landing_zone_refs

  network        = var.network
  network_static = var.network_static

  add_random_name_suffix = var.add_random_name_suffix
}

# The starterkit hands the meshProject and meshTenant over to the application team and then removes
# itself, so the team is not left with a block they cannot do anything with.
#
# This is only safe because the definition sets `deletion_mode = "PURGE"`. Under PURGE the plain
# DELETE runs no teardown at all — meshStack fabricates a successful destroy run instead of asking a
# runner for one — so the meshProject, the meshTenant and the spoke network block all stay exactly as
# this run left them. Under DELETE the same call would destroy all three.
#
# The call is the plain DELETE and not `/purge`. `/purge` needs `ADM_BUILDINGBLOCK_DELETE`, and a
# definition may only declare workspace-level permissions, so a run token can never hold it. The
# deletion mode on the definition is what turns this delete into a purge.
#
# Deleting a block whose own run is still in progress is allowed: the purge path checks only that the
# block has no children, not that it is in a deletable state. The spoke network block declares no
# parent, so it is not a child and does not block this.
resource "terraform_data" "self_purge" {
  depends_on = [module.this]

  # `meshstack_building_block_id` is this block's own uuid, and MESHSTACK_ENDPOINT and
  # MESHSTACK_API_TOKEN are exported by the runner because the definition declares permissions.
  # Retried a few times so a transient error does not strand the block; after that the run fails, and
  # the block stays visible so an operator can see the self-delete did not happen. Deleting it by
  # hand then is harmless, for the same reason this resource is.
  provisioner "local-exec" {
    environment = {
      BB_UUID = var.meshstack_building_block_id
    }

    command = <<-EOT
      for i in 1 2 3 4 5 6; do
        curl -s --fail-with-body -X DELETE \
          -H "Authorization: Bearer $MESHSTACK_API_TOKEN" \
          "$MESHSTACK_ENDPOINT/api/meshobjects/meshbuildingblocks/$BB_UUID" \
          && exit 0
        echo "Attempt $i to delete building block $BB_UUID failed, retrying in 5s..." >&2
        sleep 5
      done
      echo "Could not delete building block $BB_UUID. Everything it provisioned is in place; delete the block by hand." >&2
      exit 1
    EOT
  }
}

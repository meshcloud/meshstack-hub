# Ordering without a TTL needs no second live workspace: what is worth checking is that the order
# carries no TTL input at all, which a plan already shows. That the building block then writes no
# expiry date is covered by the mocked run.

variables {
  ttl_optional = true
}

run "meshstack_workspace_starterkit_no_ttl" {
  command = plan

  assert {
    condition     = !contains(keys(meshstack_building_block.this.spec.inputs), "workspace_ttl_days")
    error_message = "An order that leaves the TTL blank must send no workspace_ttl_days input at all."
  }
}

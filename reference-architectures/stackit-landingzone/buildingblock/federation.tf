# The claims the platform team must trust on their STACKIT service account before this architecture
# can authenticate. meshStack resolves them per definition version, and a definition cannot reference
# its own resolved identity, so the bootstrap run looks its own definition up and reports them.

data "meshstack_integrations" "this" {}

data "meshstack_building_block_definitions" "own" {
  workspace_identifier = var.workspace
}

locals {
  own_definition = one([
    for definition in data.meshstack_building_block_definitions.own.building_block_definitions
    : definition if definition.spec.display_name == var.bbd_display_name
  ])

  # The replicator subject names the replicator itself; every definition's subject shares its prefix.
  wif_subject_prefix = trimsuffix(data.meshstack_integrations.this.workload_identity_federation.replicator.subject, ":replicator")

  wif = {
    issuer   = data.meshstack_integrations.this.workload_identity_federation.replicator.issuer
    audience = "api://AzureADTokenExchange"

    # `try` swallows a null `own_definition` so the summary's precondition can name the cause,
    # rather than the run failing on an attribute of null.
    subject = "${local.wif_subject_prefix}:workspace.${var.workspace}.buildingblockdefinition.${try(local.own_definition.metadata.uuid, "")}"
  }
}

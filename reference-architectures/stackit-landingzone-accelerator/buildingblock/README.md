---
name: STACKIT Landing Zone Accelerator
supportedPlatforms:
  - stackit
description: Applies the STACKIT Landing Zone Accelerator with a STACKIT Landing Zone Configurator export, and registers a STACKIT platform whose landing zones create projects in the accelerator's landing zone folders.
---

This building block decodes the pasted Configurator export with
`provider::terraform::decode_tfvars` and passes its values to the accelerator's `src/` at
`accelerator_ref`. An input the export leaves out keeps the accelerator's default. The export may
only set the inputs `main.tf` passes on; firewall credentials and `bucket_naming` are rejected.

It then sources [`modules/stackit`](../../../modules/stackit) with `stackit_landing_zones`: one
landing zone for each of the folders `landing_zones_public` and `landing_zones_corporate` that the
export declares. The STACKIT Project definition creates a tenant's project in the folder of its
landing zone. Its service account lives in the accelerator's management project.

Every STACKIT provider of the run, the accelerator's own included, authenticates with the
`STACKIT_SERVICE_ACCOUNT_KEY` environment variable. meshStack sets it from the input of that name.

The user-facing readme is maintained inline in the `readme` field of the
`meshstack_building_block_definition` in
[`../meshstack_integration.tf`](../meshstack_integration.tf).

Its variables are declared in [`variables.tf`](variables.tf).

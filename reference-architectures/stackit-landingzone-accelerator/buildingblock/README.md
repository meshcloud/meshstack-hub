---
name: STACKIT Landing Zone Accelerator
supportedPlatforms:
  - stackit
description: Applies the STACKIT Landing Zone Accelerator with a STACKIT Landing Zone Configurator export, and registers a STACKIT platform with one landing zone per landing zone of the export.
---

This building block decodes the pasted Configurator export with
`provider::terraform::decode_tfvars` and passes its values to the accelerator's `src/` at
`accelerator_ref`, any git ref of the accelerator. The export's `Accelerator source` header names
the commit the export was made for; another ref works when the export's variables fit that version.
An input the export leaves out keeps the accelerator's default. The export may
only set the inputs `main.tf` passes on; firewall credentials and `bucket_naming` are rejected.

It then sources [`modules/stackit`](../../../modules/stackit) with `stackit_landing_zones`: one
landing zone per entry of the export's `landing_zones`, keyed by the entry key lowercased with each
run of other characters than letters and digits turned into a dash. Its folder is the accelerator's
corporate folder when the entry's `corporate` is true or unset, and the public folder otherwise.
The STACKIT Project definition creates a tenant's project in the folder of its landing zone. An
export without landing zones gives a platform without landing zones. Its service account lives in the accelerator's management project.

Every STACKIT provider of the run, the accelerator's own included, authenticates with the
`STACKIT_SERVICE_ACCOUNT_KEY` environment variable. meshStack sets it from the input of that name.

The user-facing readme is maintained inline in the `readme` field of the
`meshstack_building_block_definition` in
[`../meshstack_integration.tf`](../meshstack_integration.tf).

Its variables are declared in [`variables.tf`](variables.tf).

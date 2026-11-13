output "on_old_runner" {
  value = {
    status      = meshstack_building_block.on_old_runner.status
    version     = meshstack_building_block.on_old_runner.spec.building_block_definition_version_ref.uuid
    bucket_name = jsondecode(meshstack_building_block.on_old_runner.status.outputs["bucket_name"].value)
  }
}

output "on_new_runner" {
  value = local.moved ? {
    status  = meshstack_building_block.on_new_runner.status
    version = meshstack_building_block.on_new_runner.spec.building_block_definition_version_ref.uuid
  } : null
}

output "runner_issuers" {
  value = {
    old = data.meshstack_building_block_runner.old.spec.workload_identity_federation.issuer
    new = data.meshstack_building_block_runner.new.spec.workload_identity_federation.issuer
  }
}

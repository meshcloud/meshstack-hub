run "building_block_ske_starterkit_hub" {
  assert {
    condition     = meshstack_building_block.this.status.status == "SUCCEEDED"
    error_message = "ske-starterkit hub building block expected SUCCEEDED, got ${meshstack_building_block.this.status.status}"
  }

  assert {
    condition     = can(regex("^https://", jsondecode(meshstack_building_block.this.status.outputs["app_link_dev"].value)))
    error_message = "ske-starterkit hub building block expected app_link_dev to be a URL, got ${jsondecode(meshstack_building_block.this.status.outputs["app_link_dev"].value)}"
  }

  assert {
    condition     = can(regex("^https://", jsondecode(meshstack_building_block.this.status.outputs["app_link_prod"].value)))
    error_message = "ske-starterkit hub building block expected app_link_prod to be a URL, got ${jsondecode(meshstack_building_block.this.status.outputs["app_link_prod"].value)}"
  }

  # The app must actually serve traffic over a valid (cert-manager-issued) TLS certificate.
  assert {
    condition     = data.external.app_probe["dev"].result.status == "200"
    error_message = "dev app endpoint expected HTTP 200 over verified TLS, got ${data.external.app_probe["dev"].result.status}"
  }

  assert {
    condition     = data.external.app_probe["prod"].result.status == "200"
    error_message = "prod app endpoint expected HTTP 200 over verified TLS, got ${data.external.app_probe["prod"].result.status}"
  }
}

run "azure_aks_hub" {
  assert {
    condition     = meshstack_building_block_v2.this.status.status == "SUCCEEDED"
    error_message = "azure/aks hub building block expected SUCCEEDED, got ${meshstack_building_block_v2.this.status.status}"
  }

  assert {
    condition     = meshstack_building_block_v2.this.status.outputs["oidc_issuer_url"].value_string != ""
    error_message = "expected oidc_issuer_url to be set"
  }
}

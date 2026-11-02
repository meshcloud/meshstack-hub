# Outputs are read through `try` because a failed run reports none, and an assertion that indexes a
# missing output errors instead of failing — which buries the status assertion.

run "azure_ai_model_endpoint" {
  assert {
    condition     = meshstack_building_block.this.status.succeeded
    error_message = "Building block run did not succeed: health status ${meshstack_building_block.this.status.health_status}, action ${meshstack_building_block.this.status.action}"
  }

  assert {
    condition     = can(regex("^https://${var.test_context.run_id}-[a-z0-9]{5}\\.openai\\.azure\\.com/$", try(jsondecode(meshstack_building_block.this.status.outputs["openai_endpoint"].value), "")))
    error_message = "Expected an OpenAI endpoint on the account's custom subdomain, got ${try(meshstack_building_block.this.status.outputs["openai_endpoint"].value, "no such output")}."
  }

  assert {
    condition     = try(jsondecode(meshstack_building_block.this.status.outputs["deployment_name"].value), null) == "gpt-4.1-mini"
    error_message = "Expected the deployment to be named after the ordered model, got ${try(meshstack_building_block.this.status.outputs["deployment_name"].value, "no such output")}."
  }

  assert {
    condition     = try(jsondecode(meshstack_building_block.this.status.outputs["resource_group"].value), null) == "rg-${var.test_context.run_id}"
    error_message = "Expected resource group rg-${var.test_context.run_id}, got ${try(meshstack_building_block.this.status.outputs["resource_group"].value, "no such output")}."
  }

  assert {
    condition     = startswith(try(jsondecode(meshstack_building_block.this.status.outputs["portal_url"].value), ""), "https://portal.azure.com/#@")
    error_message = "Expected portal_url to deeplink the Azure Portal, got ${try(meshstack_building_block.this.status.outputs["portal_url"].value, "no such output")}."
  }
}

run "building_block_gcp_budget_alert_hub" {
  assert {
    condition     = meshstack_building_block.this.status.status == "SUCCEEDED"
    error_message = "gcp budget-alert hub building block expected SUCCEEDED, got ${meshstack_building_block.this.status.status}"
  }

  assert {
    condition     = startswith(jsondecode(meshstack_building_block.this.status.outputs["budget_id"].value), "billingAccounts/${var.test_context.fixtures.gcp.billing_account_id}/budgets/")
    error_message = "gcp budget-alert hub building block expected budget_id under the fixtures billing account, got ${jsondecode(meshstack_building_block.this.status.outputs["budget_id"].value)}"
  }

  assert {
    condition     = startswith(jsondecode(meshstack_building_block.this.status.outputs["budget_url"].value), "https://console.cloud.google.com/billing/${var.test_context.fixtures.gcp.billing_account_id}/budgets/")
    error_message = "gcp budget-alert hub building block expected budget_url to link the budget in the GCP console, got ${jsondecode(meshstack_building_block.this.status.outputs["budget_url"].value)}"
  }

  # The notification channel is the part that needs monitoring.googleapis.com enabled on the
  # backplane project, so assert it really came into existence.
  assert {
    condition     = startswith(jsondecode(meshstack_building_block.this.status.outputs["notification_channel_id"].value), "projects/${var.test_context.fixtures.gcp.project_id}/notificationChannels/")
    error_message = "gcp budget-alert hub building block expected notification_channel_id in the backplane project, got ${jsondecode(meshstack_building_block.this.status.outputs["notification_channel_id"].value)}"
  }

  assert {
    condition     = strcontains(jsondecode(meshstack_building_block.this.status.outputs["summary"].value), "## Budget Alert: smoke-test-gcp-budget-${var.test_context.name_suffix}")
    error_message = "gcp budget-alert hub building block expected summary to name the requested budget, got ${jsondecode(meshstack_building_block.this.status.outputs["summary"].value)}"
  }

  assert {
    condition     = strcontains(jsondecode(meshstack_building_block.this.status.outputs["summary"].value), "**Monthly budget**: 100000 EUR")
    error_message = "gcp budget-alert hub building block expected summary to report the requested budget amount, got ${jsondecode(meshstack_building_block.this.status.outputs["summary"].value)}"
  }

  # Proves the double-encoded CODE input arrived as the YAML the building block decodes, rather than
  # the definition's default thresholds.
  assert {
    condition     = strcontains(jsondecode(meshstack_building_block.this.status.outputs["summary"].value), "| 42% | ACTUAL |")
    error_message = "gcp budget-alert hub building block expected summary to report the requested threshold, got ${jsondecode(meshstack_building_block.this.status.outputs["summary"].value)}"
  }
}

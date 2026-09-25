# Mode-agnostic: asserts on the building block only, so it runs unchanged whether the definition was
# built from hub source or already deployed by a foundation.
run "aws_budget_alert" {
  assert {
    condition     = meshstack_building_block.this.status.status == "SUCCEEDED"
    error_message = "aws budget-alert building block expected SUCCEEDED, got ${meshstack_building_block.this.status.status}"
  }

  assert {
    condition     = jsondecode(meshstack_building_block.this.status.outputs["budget_name"].value) == "${var.test_context.run_id}-budget"
    error_message = "aws budget-alert building block expected budget_name to be '${var.test_context.run_id}-budget', got ${jsondecode(meshstack_building_block.this.status.outputs["budget_name"].value)}"
  }

  assert {
    condition     = jsondecode(meshstack_building_block.this.status.outputs["budget_amount"].value) == var.monthly_budget_amount
    error_message = "aws budget-alert building block expected budget_amount to be ${var.monthly_budget_amount}, got ${jsondecode(meshstack_building_block.this.status.outputs["budget_amount"].value)}"
  }

  # The budget id is `<account id>:<budget name>`. A 12-digit account id in front of the name is what
  # proves the budget was created in the target account the backplane assumed a role into, rather
  # than the name simply being echoed back.
  assert {
    condition     = can(regex("^[0-9]{12}:${var.test_context.run_id}-budget$", jsondecode(meshstack_building_block.this.status.outputs["budget_id"].value)))
    error_message = "aws budget-alert building block expected budget_id to be '<account id>:${var.test_context.run_id}-budget', got ${jsondecode(meshstack_building_block.this.status.outputs["budget_id"].value)}"
  }
}

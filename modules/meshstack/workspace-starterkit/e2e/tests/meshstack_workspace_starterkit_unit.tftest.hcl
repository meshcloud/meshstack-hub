# Expiry tracking switched off, as the building block sees it. Covers what the live case cannot:
# the workspace's tags and the payment method's expiration date are not declared outputs, and
# reading them back needs admin read on a workspace the test's credential does not own.

mock_provider "meshstack" {}

run "no_ttl_leaves_nothing_with_an_expiry_date" {
  command = plan

  module {
    source = "../buildingblock"
  }

  variables {
    # workspace_ttl_days is deliberately unset — that is the state under test.
    workspace_identifier     = "ws1"
    workspace_display_name   = "Workspace One"
    workspace_expiry_tag_key = "expiry"
    workspace_owner_username = "owner@example.com"
    workspace_role_name      = "Workspace Owner"
    payment_method_amount    = 100
    project_identifier       = "proj1"
    project_display_name     = "Project One"
    project_role_name        = "Project Admin"
    platform_ref             = { uuid = "00000000-0000-0000-0000-000000000000" }
    landing_zone_ref         = { name = "lz" }
    tags = {
      workspace      = { env = ["test"] }
      payment_method = {}
      project        = {}
    }
  }

  assert {
    condition     = output.workspace_expiry_date == null
    error_message = "A block ordered without a TTL must report no expiry date."
  }

  assert {
    condition     = !contains(keys(meshstack_workspace.this.metadata.tags), "expiry")
    error_message = "A workspace ordered without a TTL must carry no expiry tag."
  }

  assert {
    condition     = meshstack_payment_method.this.spec.expiration_date == null
    error_message = "A payment method must not expire when the workspace it belongs to does not."
  }
}

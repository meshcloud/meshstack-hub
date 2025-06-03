run "verify" {
  variables {
    budget_name           = "integrationtest"
    contact_email         = "foo@example.com"
    monthly_budget_amount = 100
  }

  assert {
    condition     = output.budget_id != null
    error_message = "did not produce a budget id"
  }
}
# terraform test is cool because it does the apply and destroy lifecycle
# what it doesn't test though is the backend storage. if we want to test that, we need to that via terragrunt

run "verify" {
  variables {
    budget_name           = "integrationtest"
    contact_emails        = "foo@example.com, bar@example.com"
    monthly_budget_amount = 100
  }

  assert {
    condition     = output.budget_amount == 100
    error_message = "did not produce the correct budget_amount output"
  }
}

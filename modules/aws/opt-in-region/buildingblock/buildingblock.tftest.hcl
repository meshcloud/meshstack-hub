# terraform test is cool because it does the apply and destroy lifecycle
# what it doesn't test though is the backend storage. if we want to test that, we need to that via terragrunt

run "verify" {
  variables {
    region  = "eu-south-2"
    enabled = true
  }

  assert {
    condition     = output.opt_status == "ENABLED"
    error_message = "incorrect opt-in status for region ${var.region}"
  }
}

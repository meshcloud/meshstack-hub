config {
  # Module sources pin a git ref that tflint must not fetch; see ci/tflint.sh.
  call_module_type = "none"
}

plugin "terraform" {
  enabled = true
  preset  = "all"
  version = "0.17.0"
  source  = "github.com/terraform-linters/tflint-ruleset-terraform"
}

plugin "azurerm" {
  enabled = true
  version = "0.33.0"
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}

plugin "aws" {
  enabled = true
  version = "0.50.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

plugin "google" {
  enabled = true
  version = "0.41.0"
  source  = "github.com/terraform-linters/tflint-ruleset-google"
}

# Hub splits a module into backplane/, buildingblock/ and meshstack_integration.tf.
rule "terraform_standard_module_structure" {
  enabled = false
}

# A buildingblock declares the providers its runner configures, used or not.
rule "terraform_unused_required_providers" {
  enabled = false
}

rule "terraform_documented_variables" {
  enabled = false
}

rule "terraform_documented_outputs" {
  enabled = false
}

# A building block's destroy run must be able to delete what it created.
rule "azurerm_resources_missing_prevent_destroy" {
  enabled = false
}

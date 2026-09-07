terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      # azurerm 5.4.0 added a migration-status read to every Storage Account encode (including
      # destroy), which the smoke-test's Azure credential isn't authorized for (AuthorizationFailed
      # on Microsoft.Storage/storageAccounts/accountMigrations/read). Cap below it until that's
      # resolved: https://github.com/meshcloud/meshstack-smoke-test/actions/runs/34083993918/job/101624479617
      version = ">= 4.65.0, < 5.4.0"
    }
  }
}


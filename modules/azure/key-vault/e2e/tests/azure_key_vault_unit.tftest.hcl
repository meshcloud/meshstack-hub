# The live run orders against one fixture subscription, so it never sees how a subscription name is
# turned into a vault and a resource group name. These runs mock the subscription instead.

mock_provider "azurerm" {
  # The vault validates tenant_id as a UUID, which a generated mock value is not.
  mock_data "azurerm_client_config" {
    defaults = {
      tenant_id = "00000000-0000-0000-0000-000000000000"
    }
  }
}

mock_provider "azurerm" {
  alias = "hub"
}

mock_provider "random" {
  mock_resource "random_string" {
    defaults = {
      result = "x7k2q"
    }
  }
}

variables {
  subscription_id = "00000000-0000-0000-0000-000000000000"
  location        = "germanywestcentral"
}

run "names_from_subscription" {
  module {
    source = "../buildingblock"
  }

  override_data {
    target = data.azurerm_subscription.current
    values = {
      display_name = "UCL Demo.Payments_Service 2026"
    }
  }

  assert {
    condition     = azurerm_key_vault.key_vault.name == "kv-ucl-demo-paymen-x7k2q"
    error_message = "Expected the vault name to carry the first 15 characters of the slugged subscription name, got ${azurerm_key_vault.key_vault.name}."
  }

  assert {
    condition     = azurerm_resource_group.key_vault.name == "rg-ucl-demo-payments-service-2026-kv"
    error_message = "Expected the resource group to carry the whole slugged subscription name, got ${azurerm_resource_group.key_vault.name}."
  }
}

run "cut_at_a_dash" {
  module {
    source = "../buildingblock"
  }

  # The 15th character is the dash, which a vault name may not end its prefix with before the
  # suffix's own dash: "--" is not allowed.
  override_data {
    target = data.azurerm_subscription.current
    values = {
      display_name = "abcdefghijklmn-rest"
    }
  }

  assert {
    condition     = azurerm_key_vault.key_vault.name == "kv-abcdefghijklmn-x7k2q"
    error_message = "Expected the trailing dash of the cut slug to be dropped, got ${azurerm_key_vault.key_vault.name}."
  }
}

run "explicit_names_win" {
  module {
    source = "../buildingblock"
  }

  variables {
    key_vault_name                = "payments"
    key_vault_resource_group_name = "rg-payments"
  }

  override_data {
    target = data.azurerm_subscription.current
    values = {
      display_name = "UCL Demo"
    }
  }

  assert {
    condition     = azurerm_key_vault.key_vault.name == "payments-x7k2q"
    error_message = "Expected the ordered name to be used, got ${azurerm_key_vault.key_vault.name}."
  }

  assert {
    condition     = azurerm_resource_group.key_vault.name == "rg-payments"
    error_message = "Expected the ordered resource group to be used, got ${azurerm_resource_group.key_vault.name}."
  }
}

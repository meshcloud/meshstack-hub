terraform {
  required_version = ">= 1.3.0"
  required_providers {
    # Held on azurerm 3.x: from 4.0 on, azurerm_monitor_activity_log_alert requires a
    # `location`, which the four alerts in main.tf do not set, so the module does not even
    # validate on 4.x. Add `location` to those four before raising this floor.
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.116.0, < 4.0.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.11.1, < 1.0.0"
    }
  }
}
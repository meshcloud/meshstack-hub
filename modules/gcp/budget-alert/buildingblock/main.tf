locals {
  alert_thresholds = yamldecode(var.alert_thresholds_yaml)
}

resource "google_billing_budget" "budget" {
  billing_account = var.billing_account_id

  budget_filter {
    projects = ["projects/${var.project_id}"]
  }

  display_name = var.budget_name
  amount {
    specified_amount {
      currency_code = var.budget_currency
      units         = var.monthly_budget_amount
    }
  }

  # Threshold rules for warning and critical alerts
  dynamic "threshold_rules" {
    for_each = local.alert_thresholds

    content {
      threshold_percent = tonumber(threshold_rules.value.percent) / 100
      spend_basis = lookup(
        {
          "ACTUAL"     = "CURRENT_SPEND"
          "FORECASTED" = "FORECASTED_SPEND"
        },
        threshold_rules.value.basis,
        threshold_rules.value.basis
      )
    }
  }

  all_updates_rule {
    monitoring_notification_channels = [
      google_monitoring_notification_channel.notification_channel.id,
    ]
    disable_default_iam_recipients = true
  }
}

resource "google_monitoring_notification_channel" "notification_channel" {
  project      = var.backplane_project_id
  display_name = "Notification Channel for budget alert ${var.budget_name} on project ${var.project_id}"
  type         = "email"

  labels = {
    email_address = var.contact_email
  }
}
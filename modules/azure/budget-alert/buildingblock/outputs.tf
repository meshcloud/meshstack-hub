output "budget_amount" {
  value = azurerm_consumption_budget_subscription.subscription_budget.amount
}

output "summary" {
  description = "Markdown summary of the created budget"
  value       = <<-EOT
    ## Budget Alert: ${var.budget_name}

    - **Subscription**: ${var.subscription_id}
    - **Monthly budget**: ${azurerm_consumption_budget_subscription.subscription_budget.amount}

    | Threshold | Basis |
    |---|---|
    | ${var.actual_threshold_percent}% | Actual |
    | ${var.forcasted_threshold_percent}% | Forecasted |

    Alerts are delivered to:

    ${join("\n", [for email in local.contact_emails_list : "- ${email}"])}
  EOT
}

output "budget_id" {
  description = "The ID of the created budget"
  value       = google_billing_budget.budget.id
}

output "budget_url" {
  description = "Link to the budget in the GCP console"
  value       = "https://console.cloud.google.com/billing/${var.billing_account_id}/budgets/${basename(google_billing_budget.budget.id)}"
}

output "notification_channel_id" {
  description = "The ID of the Cloud Monitoring notification channel the budget alerts are delivered to"
  value       = google_monitoring_notification_channel.notification_channel.id
}

output "summary" {
  description = "Markdown summary of the created budget"
  value       = <<-EOT
    ## Budget Alert: ${var.budget_name}

    - **Project**: ${var.project_id}
    - **Monthly budget**: ${var.monthly_budget_amount} ${var.budget_currency}
    - **Alerts to**: ${var.contact_email}

    | Threshold | Basis |
    |---|---|
    ${join("\n", [for t in local.alert_thresholds : "| ${t.percent}% | ${t.basis} |"])}

    Budget alert emails are sent by Cloud Monitoring; the default IAM recipients (billing account
    admins and users) are deliberately not notified.
  EOT
}

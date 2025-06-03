output "budget_id" {
  description = "The ID of the created budget"
  value       = google_billing_budget.budget.id
}
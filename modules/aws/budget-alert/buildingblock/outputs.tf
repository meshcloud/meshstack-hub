output "budget_id" {
  description = "The ID of the budget"
  value       = aws_budgets_budget.account_budget.id
}

output "budget_name" {
  description = "The name of the budget"
  value       = aws_budgets_budget.account_budget.name
}

output "budget_amount" {
  description = "The amount of the budget"
  value       = tonumber(aws_budgets_budget.account_budget.limit_amount)
}
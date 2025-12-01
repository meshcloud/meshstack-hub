# meshStack Payment Method Building Block

This Terraform module creates a payment method for a specific workspace in meshStack.

## Features
- Create payment methods with configurable budgets
- Optional expiration dates
- Flexible tagging support

## Usage

```hcl
module "payment_method" {
  source = "./modules/meshstack/payment-method/buildingblock"

  payment_method_name = "dev-team-budget"
  workspace_id        = "workspace-abc123"
  amount              = 10000
  expiration_date     = "2025-12-31T23:59:59Z"
  
  tags = {
    team        = "development"
    environment = "production"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| meshstack | ~> 0.1.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| payment_method_name | Name of the payment method | string | "default-payment-method" | no |
| workspace_id | The ID of the workspace to which this payment method will be assigned | string | n/a | yes |
| amount | The budget amount for this payment method | number | n/a | yes |
| expiration_date | The expiration date in RFC3339 format (e.g., '2025-12-31T23:59:59Z') | string | null | no |
| tags | Additional tags to apply to the payment method | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| payment_method_id | The ID of the created payment method |
| payment_method_name | The name of the payment method |
| workspace_id | The workspace ID associated with this payment method |
| amount | The budget amount for this payment method |

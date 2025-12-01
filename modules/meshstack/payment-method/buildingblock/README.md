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

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_meshstack"></a> [meshstack](#requirement\_meshstack) | ~> 0.14.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [meshstack_payment_method.payment_method](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/payment_method) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_amount"></a> [amount](#input\_amount) | The budget amount for this payment method | `number` | n/a | yes |
| <a name="input_expiration_date"></a> [expiration\_date](#input\_expiration\_date) | The expiration date of the payment method in RFC3339 format (e.g., '2025-12-31T23:59:59Z') | `string` | `null` | no |
| <a name="input_payment_method_name"></a> [payment\_method\_name](#input\_payment\_method\_name) | Name of the payment method | `string` | `"default-payment-method"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags to apply to the payment method | `map(string)` | `{}` | no |
| <a name="input_workspace_id"></a> [workspace\_id](#input\_workspace\_id) | The ID of the workspace to which this payment method will be assigned | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_amount"></a> [amount](#output\_amount) | The budget amount for this payment method |
| <a name="output_payment_method_id"></a> [payment\_method\_id](#output\_payment\_method\_id) | The ID of the created payment method |
| <a name="output_payment_method_name"></a> [payment\_method\_name](#output\_payment\_method\_name) | The name of the payment method |
| <a name="output_workspace_id"></a> [workspace\_id](#output\_workspace\_id) | The workspace ID associated with this payment method |
<!-- END_TF_DOCS -->
output "some_file_yaml" {
  value = yamldecode(file("some-file.yaml"))
}

output "sensitive_file_yaml" {
  value = yamldecode(file("sensitive-file.yaml"))
}

output "user_permissions" {
  value = var.user_permissions
}

output "user_permissions_json" {
  value = jsondecode(var.user_permissions_json)
}

output "sensitive_yaml" {
  value     = var.sensitive_yaml
  sensitive = true
}

output "static" {
  value = var.static
}

output "static_code" {
  value = var.static_code
}

output "flag" {
  value = var.flag
}

output "num" {
  value = var.num
}

output "text" {
  value = var.text
}

output "sensitive_text" {
  value     = var.sensitive_text
  sensitive = true
}

output "single_select" {
  value = var.single_select
}

output "multi_select" {
  value = var.multi_select
}

output "multi_select_json" {
  value = jsondecode(var.multi_select_json)
}

output "resource_url" {
  value = "https://hub.meshcloud.io/modules/meshstack/noop"
}

output "summary" {
  value = <<-MARKDOWN
# NoOp Building Block — Deployment Summary

This building block was successfully deployed. It is a **reference implementation**
demonstrating meshStack's complete Terraform interface — it provisions _no real
infrastructure_.

The `SUMMARY` output assignment type allows you to provide a rich markdown summary for application teams.
This summary is rendered like a README for this building block in meshPanel.

## Example: Tables

| Input          | Value                        |
|----------------|------------------------------|
| Text           | `${var.text}`                |
| Number         | `${var.num}`                 |
| Flag           | `${var.flag}`                |
| Single Select  | `${var.single_select}`       |
| Multi Select   | `${join(", ", var.multi_select)}` |

## Example: Code blocks

You can use fenced code blocks and `inline code` for formatting.
We support syntax highlighting for common languages.

```yaml
some: input
other: value
```

## Example: Callout blocks

> **Note**: Use quote blocks to create callouts for important information.
MARKDOWN
}

output "debug_input_variables_json" {
  description = "JSON-encoded map of all input variables received, including sensitive values in plaintext."
  sensitive   = true # For test only. Do not do this in production code.
  value = jsonencode({
    flag                  = var.flag
    num                   = var.num
    text                  = var.text
    single_select         = var.single_select
    sensitive_text        = var.sensitive_text
    sensitive_yaml        = var.sensitive_yaml
    multi_select          = var.multi_select
    multi_select_json     = var.multi_select_json
    static                = var.static
    static_code           = var.static_code
    user_permissions      = var.user_permissions
    user_permissions_json = var.user_permissions_json
  })
}

output "debug_input_files_json" {
  description = "JSON-encoded map of all input files received, including sensitive values in plaintext."
  sensitive   = true # For test only. Do not do this in production code.
  value = jsonencode({
    "some-file.yaml"      = file("some-file.yaml")
    "sensitive-file.yaml" = file("sensitive-file.yaml")
  })
}

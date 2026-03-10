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

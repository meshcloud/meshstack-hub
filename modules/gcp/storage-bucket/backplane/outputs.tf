output "credentials_json" {
  sensitive = true
  value     = base64decode(google_service_account_key.buildingblock_storage_key.private_key)
}

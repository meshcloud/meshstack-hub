provider "stackit" {
  # Secrets Manager is a regional service. The API endpoint in outputs.tf is fixed to this region.
  default_region = "eu01"
}

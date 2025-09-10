resource "google_storage_bucket" "main" {
  name     = var.bucket_name
  location = var.location

  # Convert labels list to map for Google Cloud
  labels = {
    for label in var.labels :
    split(":", label)[0] => split(":", label)[1]
  }
}

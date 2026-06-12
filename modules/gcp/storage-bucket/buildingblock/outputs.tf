output "bucket_name" {
  value = google_storage_bucket.main.name
}

output "bucket_url" {
  value = "https://console.cloud.google.com/storage/browser/${google_storage_bucket.main.name}?project=${google_storage_bucket.main.project}"
}

output "summary" {
  description = "Markdown summary output of the building block"
  value       = <<EOT
# GCP Storage Bucket

Your GCP Storage Bucket was successfully created!

## Details

- **Name**: ${google_storage_bucket.main.name}
- **Project**: ${google_storage_bucket.main.project}
- **Location**: ${google_storage_bucket.main.location}
- **gsutil URI**: `${google_storage_bucket.main.url}`
- [Open in GCP Console](https://console.cloud.google.com/storage/browser/${google_storage_bucket.main.name}?project=${google_storage_bucket.main.project})

EOT
}

output "bucket_name" {
  value = google_storage_bucket.main.name
}

output "bucket_url" {
  value = google_storage_bucket.main.url
}

output "bucket_self_link" {
  value = google_storage_bucket.main.self_link
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
- **URL**: ${google_storage_bucket.main.url}
- **Self Link**: ${google_storage_bucket.main.self_link}

EOT
}
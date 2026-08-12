# Must create bucket as S3 user in order to assign bucket policies.
# We use the AWS provider as a generic S3 provider.
# If we create it with the stackit_provider we don't have permissions.
resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name

  # Bucket deletion will fail if not empty. We need to keep the credentials so
  # that objects can still be deleted in such a case.
  depends_on = [stackit_objectstorage_credential.this]
}

resource "stackit_objectstorage_credentials_group" "this" {
  project_id = var.project_id
  name       = var.bucket_name
}

resource "stackit_objectstorage_credential" "this" {
  project_id           = var.project_id
  credentials_group_id = stackit_objectstorage_credentials_group.this.credentials_group_id
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.bucket

  policy = jsonencode({
    Statement = [
      {
        Sid    = "restrict-to-credentials-group"
        Effect = "Deny"
        NotPrincipal = {
          AWS = [
            stackit_objectstorage_credentials_group.this.urn,
            var.admin_credentials_group_urn,
          ]
        }
        Action = ["s3:*"]
        Resource = [
          "urn:sgws:s3:::${aws_s3_bucket.this.bucket}",
          "urn:sgws:s3:::${aws_s3_bucket.this.bucket}/*",
        ]
      },
      {
        Sid    = "allow-credentials-group-read-write"
        Effect = "Allow"
        Principal = {
          AWS = stackit_objectstorage_credentials_group.this.urn
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          # Multipart uploads: creating, uploading and completing parts is covered by s3:PutObject,
          # but cancelling an upload and finding leftover parts are separate actions. Clients such as
          # the AWS SDK upload helpers call AbortMultipartUpload when an upload fails part-way, and
          # without these the abort returns 403 and the orphaned parts stay in the bucket.
          "s3:AbortMultipartUpload",
          "s3:ListMultipartUploadParts",
          "s3:ListBucketMultipartUploads",
        ]
        Resource = [
          "urn:sgws:s3:::${aws_s3_bucket.this.bucket}",
          "urn:sgws:s3:::${aws_s3_bucket.this.bucket}/*",
        ]
      },
      {
        Sid    = "allow-admin-bucket-policy-management"
        Effect = "Allow"
        Principal = {
          AWS = var.admin_credentials_group_urn
        }
        Action = [
          "s3:GetBucketPolicy",
          "s3:PutBucketPolicy",
          "s3:DeleteBucketPolicy",
        ]
        Resource = [
          "urn:sgws:s3:::${aws_s3_bucket.this.bucket}",
        ]
      },
    ]
  })
}

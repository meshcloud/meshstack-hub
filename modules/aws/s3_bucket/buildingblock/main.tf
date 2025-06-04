resource "aws_s3_bucket" "main" {
  bucket = var.bucket_name
  tags = {
    for tag in var.tags :
    split(":", tag)[0] => split(":", tag)[1]
  }
}

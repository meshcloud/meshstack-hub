resource "terraform_data" "noop" {
  # This resource does nothing and is always up-to-date.
}

resource "terraform_data" "aws_cli" {
  # Demonstrate that we can call aws cli installed in the prerun script

  provisioner "local-exec" {
    command     = <<-EOT
      version=$(aws --version 2>&1)
      echo "$version"
      echo "$version" | grep -q '^aws-cli/2' || { echo "ERROR: aws-cli v2 is required, got: $version"; exit 1; }
    EOT
    interpreter = ["bash", "-c"]
  }
}

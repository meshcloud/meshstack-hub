resource "terraform_data" "noop" {
  # This resource does nothing and is always up-to-date.
}

data "external" "aws_version" {
  # Demonstrate that we can call aws cli installed in the prerun script.
  # Validates the installed version is v2 and surfaces it as a Terraform output.
  program = ["bash", "-c", <<-EOT
    version=$(aws --version 2>&1)
    echo "{\"version\": \"$version\"}"
  EOT
  ]
}

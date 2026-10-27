resource "terraform_data" "noop" {
  # This resource does nothing and is always up-to-date.
}

data "external" "aws_version" {
  # Demonstrate that Terraform can call a tool from the module's own flake, so the pre-run
  # does not have to install it on the runner.
  program = ["bash", "-c", <<-EOT
    set -euo pipefail
    version=$(nix shell ./nix#awscli2 --command aws --version)
    echo "{\"version\": \"$version\"}"
  EOT
  ]
}

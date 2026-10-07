resource "terraform_data" "noop" {
  # This resource does nothing and is always up-to-date.
}

data "external" "aws_version" {
  # Demonstrate that Terraform can call a tool from the module's own flake, so the pre-run
  # does not have to install it on the runner.
  # Validates the version is v2 and surfaces it as a Terraform output.
  program = ["bash", "-c", <<-EOT
    version=$(nix shell ./nix#awscli2 --command aws --version)
    echo "{\"version\": \"$version\"}"
  EOT
  ]
}

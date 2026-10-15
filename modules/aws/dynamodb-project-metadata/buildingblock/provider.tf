provider "aws" {
  region = var.aws_region
}

provider "meshstack" {
  # configured via environment variables (MESHSTACK_ENDPOINT, MESHSTACK_API_KEY)
}

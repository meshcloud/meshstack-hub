terraform {
  required_providers {
    forgejo = {
      source = "svalabs/forgejo"
    }
  }
}

provider "forgejo" {
  host      = var.forgejo_host
  api_token = var.forgejo_api_token
}

terraform {
  required_providers {
    forgejo = {
      source = "svalabs/forgejo"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.35.1"
    }
  }
}

# provide the following env variables for this Building Block:
# FORGEJO_HOST
# FORGEJO_API_TOKEN
provider "forgejo" {
}

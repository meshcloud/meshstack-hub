terraform {
  required_version = ">= 1.3.0"

  required_providers {
    gitea = {
      source  = "Lerentis/gitea"
      version = "~> 0.16.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2.3"
    }
  }
}

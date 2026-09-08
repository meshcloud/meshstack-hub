terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 7.0, < 8.0.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9, < 1.0.0"
    }
  }
}

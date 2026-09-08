terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.12.0, < 7.0.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9, < 1.0.0"
    }
  }
}

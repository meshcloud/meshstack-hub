terraform {
  backend "gcs" {
    bucket = "meshcloud-tf-states"
    prefix = "meshcloud-prod/meshstack-hub/amplify"
  }
}

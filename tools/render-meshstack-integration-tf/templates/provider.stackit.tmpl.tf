provider "stackit" {
  # Configure authentication e.g. by setting STACKIT_SERVICE_ACCOUNT_KEY_PATH
  # to point to you credentials file.
  # Most integrations have to deal with setting up service accounts which
  # requires this flag.
  experiments = ["IAM"]
}

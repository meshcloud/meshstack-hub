# Credentials come from OS_AUTH_URL, OS_DOMAIN_NAME, OS_ACCESS_KEY and OS_SECRET_KEY. No
# tenant_name: the user's roles are domain-scoped, and a project-scoped token would not carry them.
provider "opentelekomcloud" {
  region = var.region
}

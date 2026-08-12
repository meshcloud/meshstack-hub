# One provider configuration reaches both projects. STACKIT credentials identify a service
# account, not a project, and every resource names its own `project_id`.
#
# Callers that drive this module from their own root configuration usually replace this file with a
# generated `provider.tf`. In that case `service_account_email` and `stackit_region` stay unset and
# the generated block carries the credentials instead — it then has to set `experiments` too.
provider "stackit" {
  default_region        = var.stackit_region
  service_account_email = var.service_account_email
  use_oidc              = true

  # stackit_authorization_project_role_assignment sits behind the provider's `iam` experiment.
  experiments = ["iam"]
}

data "external" "stackit_access_token" {
  program = ["bash", "${path.module}/stackit-access-token.sh"]
}

resource "random_string" "name_suffix" {
  length  = 4
  special = false
  upper   = false
}

locals {
  # `external` results are never marked sensitive, so the token is marked here instead.
  stackit_access_token          = sensitive(data.external.stackit_access_token.result.access_token)
  stackit_service_account_email = data.external.stackit_access_token.result.service_account_email

  service_id = "cloud.stackit.container-registry"

  # Deleting an artifactory is a soft delete, and the name it held stays taken — recreating one under
  # the same name answers 409 for good. So the caller names the registry and this adds a suffix that
  # makes the name disposable. It lives in state, so a rerun keeps the same registry; only a genuinely
  # new one draws a new suffix.
  registry_name = "${var.registry_name}-${random_string.name_suffix.result}"

  registry_host = "registry.onstackit.cloud"

  # Harbor addresses a project by a numeric id, so the browser link is
  # `<host>/harbor/projects/<id>/repositories` rather than `<host>/<name>`. That id only appears once
  # Harbor has provisioned the project, which is what read-artifactory.sh waits for.
  registry_url = data.external.artifactory.result.url

  # Same Harbor project, its Robot Accounts tab — where the bootstrap robot is created by hand.
  registry_robot_url = replace(local.registry_url, "/repositories", "/robot-account")

  service_enablement_path = "/v2/projects/${var.stackit_project_id}/regions/${var.stackit_region}/services"
  artifactory_path        = "/v1/projects/${var.stackit_project_id}/regions/${var.stackit_region}/artifactories"

  registry_role_assignments = {
    for assignment in flatten([
      for user in var.users : [
        for registry_role in distinct(flatten([
          for meshstack_role in user.roles : lookup(var.role_mapping, meshstack_role, [])
          ])) : {
          key     = "${user.email}:${registry_role}"
          subject = user.email
          role    = registry_role
        }
      ]
    ]) : assignment.key => assignment
  }
}

# `cloud.stackit.container-registry` is DISABLED by default on a fresh project, unlike
# `cloud.stackit.git`, so it is switched on before the artifactory below is created. Create is a
# POST on the service itself rather than on the collection; read and destroy take the `path/{id}`
# default.
resource "restapi_object" "service_enablement" {
  provider = restapi.service_enablement

  path        = local.service_enablement_path
  create_path = "${local.service_enablement_path}/{id}"

  object_id = local.service_id
  data      = jsonencode({})

  ignore_server_additions = true
}

# Enabling the service is asynchronous, so ordering the artifactory after it is not enough: until
# reconciliation finishes the registry API answers `403 Service not enabled`. The script polls the
# service's own state rather than sleeping for a guessed duration.
resource "terraform_data" "service_enabled" {
  triggers_replace = [restapi_object.service_enablement.id]

  provisioner "local-exec" {
    command = "${path.module}/wait-for-service-enabled.sh"

    environment = {
      ACCESS_TOKEN = local.stackit_access_token
      PROJECT_ID   = var.stackit_project_id
      REGION       = var.stackit_region
      SERVICE_ID   = local.service_id
    }
  }
}

resource "restapi_object" "artifactory" {
  provider   = restapi.registry
  depends_on = [terraform_data.service_enabled]

  path = local.artifactory_path

  # The API identifies an artifactory by a uuid it assigns, not by its name, so read, update and
  # destroy all address `artifactories/{uuid}`. The uuid comes from the create response, which is
  # why the provider sets `create_returns_object`. Naming `name` as the id instead sends the name
  # down those paths and the API rejects it: `parameter "artifactoryId" in path has an error:
  # minimum string length is 36`.
  id_attribute = "id"

  # PATCH, the only update this endpoint has, carries `proxy` and nothing else — a name is fixed for
  # the artifactory's life, so a new one means a new artifactory.
  force_new = ["name"]

  data = jsonencode({
    name = local.registry_name
  })

  ignore_server_additions = true
}

data "external" "artifactory" {
  program = ["bash", "${path.module}/read-artifactory.sh"]

  query = {
    project_id     = var.stackit_project_id
    region         = var.stackit_region
    artifactory_id = restapi_object.artifactory.id
  }
}

# Project members reach the registry through STACKIT IAM, not through Harbor's own member list: a
# `container-registry.artifactory.*` role on the STACKIT project is what makes the Harbor project
# appear for that user, and STACKIT onboards the Harbor account on their first sign-in. Verified
# live — a user who saw nothing in Harbor saw the project right after the role was granted.
resource "stackit_authorization_project_role_assignment" "registry_users" {
  for_each = local.registry_role_assignments

  depends_on = [restapi_object.artifactory]

  resource_id = var.stackit_project_id
  role        = each.value.role
  subject     = each.value.subject
}

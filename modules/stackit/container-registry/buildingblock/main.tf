data "external" "stackit_access_token" {
  program = ["bash", "${path.module}/stackit-access-token.sh"]
}

locals {
  # `external` results are never marked sensitive, so the token is marked here instead.
  stackit_access_token = sensitive(data.external.stackit_access_token.result.access_token)

  service_id = "cloud.stackit.container-registry"

  registry_host = "registry.onstackit.cloud"
  registry_url  = "https://${local.registry_host}/${var.registry_name}"

  service_enablement_path = "/v2/projects/${var.stackit_project_id}/regions/${var.stackit_region}/services"
  artifactory_path        = "/v1/projects/${var.stackit_project_id}/regions/${var.stackit_region}/artifactories"
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

resource "restapi_object" "artifactory" {
  provider   = restapi.registry
  depends_on = [restapi_object.service_enablement]

  path = local.artifactory_path

  id_attribute = "name"
  object_id    = var.registry_name

  data = jsonencode({
    name = var.registry_name
  })

  ignore_server_additions = true
}

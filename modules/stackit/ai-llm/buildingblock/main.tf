data "external" "stackit_access_token" {
  program = ["bash", "${path.module}/stackit-access-token.sh"]
}

locals {
  stackit_access_token = sensitive(data.external.stackit_access_token.result.access_token)

  service_id              = "cloud.stackit.model-serving"
  service_enablement_path = "/v2/projects/${var.stackit_project_id}/regions/${var.stackit_region}/services"

  base_url = "https://api.openai-compat.model-serving.${var.stackit_region}.onstackit.cloud/v1"
}

# `cloud.stackit.model-serving` is DISABLED by default on a fresh project, so it is switched on
# before the token below is minted. Create is a POST on the service itself rather than on the
# collection; read and destroy take the `path/{id}` default.
resource "restapi_object" "service_enablement" {
  provider = restapi.service_enablement

  path        = local.service_enablement_path
  create_path = "${local.service_enablement_path}/{id}"

  object_id = local.service_id
  data      = jsonencode({})

  ignore_server_additions = true
}

# Enabling the service is asynchronous, so ordering the token after it is not enough: until
# reconciliation finishes the model serving API rejects the request. The script polls the service's
# own state rather than sleeping for a guessed duration.
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

resource "stackit_modelserving_token" "this" {
  depends_on = [terraform_data.service_enabled]

  project_id  = var.stackit_project_id
  region      = var.stackit_region
  name        = var.token_name
  description = var.token_description
}

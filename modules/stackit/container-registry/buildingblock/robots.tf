locals {
  # The bootstrap robot is not a credential — it is the link this run authenticates through, and
  # its own secret is never sent. Naming it is how an operator says the link exists, which is the
  # only way to know: nothing in the API reports it.
  mint_robots = nonsensitive(var.bootstrap_robot_username != "")

  push_robot = local.mint_robots ? jsondecode(restapi_object.push_robot.create_response) : null
  pull_robot = local.mint_robots ? jsondecode(restapi_object.pull_robot.create_response) : null

  push_robot_username = local.mint_robots ? local.push_robot.name : ""
  push_robot_password = local.mint_robots ? local.push_robot.secret : ""
  pull_robot_username = local.mint_robots ? local.pull_robot.name : ""
  pull_robot_password = local.mint_robots ? local.pull_robot.secret : ""
}

# A Harbor robot is scoped to a project, and this module owns exactly one, so one push robot and one
# pull robot cover every application on the platform. Minting a pair per namespace would hand out the
# same project-wide access under more names.
#
# The robot's own secret is not the credential: Harbor answers a request carrying it exactly as it
# answers an unauthenticated one. What authenticates is the service account email as the basic-auth
# user and its STACKIT access token as the password, which Harbor resolves to the robot the portal
# linked it to. Verified live: that pair creates a robot, while a bearer header of the same token
# and the robot's own secret both come back unauthorized.
provider "restapi" {
  alias = "harbor"

  uri                  = "https://${local.registry_host}"
  username             = local.stackit_service_account_email
  password             = local.stackit_access_token
  write_returns_object = true

  retries {
    max_retries = 5
    min_wait    = 1
    max_wait    = 10
  }
}

# Harbor returns a robot's secret from the create call and never from a read, so neither resource
# reads anything back: `create_response` is what holds the secret, and a refresh would replace it
# with a copy that has none.
resource "restapi_object" "push_robot" {
  provider   = restapi.harbor
  depends_on = [restapi_object.artifactory]

  lifecycle {
    enabled = local.mint_robots
  }

  path         = "/api/v2.0/robots"
  id_attribute = "id"
  force_new    = ["name"]

  ignore_all_server_changes = true

  data = jsonencode({
    name        = "${local.registry_name}-push"
    description = "Pushes the images built by pipelines on this platform."
    duration    = -1
    level       = "project"
    permissions = [{
      kind      = "project"
      namespace = local.registry_name
      access = [
        { resource = "repository", action = "push" },
        { resource = "repository", action = "pull" },
      ]
    }]
  })
}

resource "restapi_object" "pull_robot" {
  provider   = restapi.harbor
  depends_on = [restapi_object.artifactory]

  lifecycle {
    enabled = local.mint_robots
  }

  path         = "/api/v2.0/robots"
  id_attribute = "id"
  force_new    = ["name"]

  ignore_all_server_changes = true

  data = jsonencode({
    name        = "${local.registry_name}-pull"
    description = "Pulls images into the namespaces on this platform."
    duration    = -1
    level       = "project"
    permissions = [{
      kind      = "project"
      namespace = local.registry_name
      access = [
        { resource = "repository", action = "pull" },
      ]
    }]
  })
}

resource "terraform_data" "mirrored_base_images" {
  for_each = local.mint_robots ? toset(var.mirrored_base_images) : toset([])

  depends_on = [restapi_object.push_robot]

  triggers_replace = [each.key, local.registry_name]

  provisioner "local-exec" {
    command = <<-SH
      set -euo pipefail
      export DOCKER_CONFIG="$(mktemp -d)"
      trap 'rm -rf "$DOCKER_CONFIG"' EXIT
      printf '%s' "$REGISTRY_PASSWORD" | "$CRANE" auth login "$REGISTRY_HOST" --username "$REGISTRY_USERNAME" --password-stdin
      "$CRANE" copy --platform linux/amd64 "$SOURCE_IMAGE" "$TARGET_IMAGE"
    SH

    interpreter = ["bash", "-c"]

    environment = {
      CRANE             = abspath("${path.module}/.crane/crane")
      SOURCE_IMAGE      = each.key
      TARGET_IMAGE      = "${local.registry_host}/${local.registry_name}/${reverse(split("/", each.key))[0]}"
      REGISTRY_HOST     = local.registry_host
      REGISTRY_USERNAME = local.push_robot_username
      REGISTRY_PASSWORD = local.push_robot_password
    }
  }
}

moved {
  from = restapi_object.push_robot[0]
  to   = restapi_object.push_robot
}

moved {
  from = restapi_object.pull_robot[0]
  to   = restapi_object.pull_robot
}

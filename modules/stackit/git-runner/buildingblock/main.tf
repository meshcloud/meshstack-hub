# Image ids are per-region and change as STACKIT republishes a release, so the image is resolved by
# name rather than pinned. The regex is anchored: `distro`/`version` filtering returns the ARM64
# build of the same release, which does not boot on the x86 flavors this runner uses.
data "stackit_image_v2" "runner" {
  project_id = var.stackit_project_id
  region     = var.stackit_region
  name_regex = var.image_name_regex
}

locals {
  registration_token = jsondecode(data.http.registration_token.response_body).token

  create_network = var.network_id == ""
  network_id     = local.create_network ? stackit_network.this.network_id : var.network_id
}

data "http" "registration_token" {
  url    = "${var.git_base_url}/api/v1/orgs/${var.git_organization}/actions/runners/registration-token"
  method = "GET"
  request_headers = {
    Authorization = "token ${var.forgejo_api_token}"
    Accept        = "application/json"
  }

  retry {
    attempts     = 5
    min_delay_ms = 1000
    max_delay_ms = 10000
  }

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "Could not mint a registration token for org '${var.git_organization}' (HTTP ${self.status_code}). Check the PAT has org-admin rights and that Actions is enabled on the Git instance."
    }
  }
}

resource "stackit_network" "this" {
  lifecycle {
    enabled = local.create_network
  }

  project_id         = var.stackit_project_id
  name               = var.name
  ipv4_nameservers   = ["9.9.9.9", "149.112.112.112"]
  ipv4_prefix_length = 24
  # Without routing the runner boots on an unrouted network, cannot reach code.forgejo.org to
  # download the agent or the Git instance to register, and silently never comes online.
  routed = true
}

# Left on STACKIT's default security group the runner could not reach the internet: it never
# downloaded its agent and never registered, which looked like a registration bug for a long time.
# STACKIT gives a newly created group allow-all egress rules of its own, so declaring one here would
# fail with a 409 against the rule it already made. The VM has no inbound access.
resource "stackit_security_group" "this" {
  project_id  = var.stackit_project_id
  name        = var.name
  description = "Git runner VM: outbound to the internet, no inbound access."
}

resource "stackit_network_interface" "this" {
  project_id         = var.stackit_project_id
  network_id         = local.network_id
  name               = var.name
  security_group_ids = [stackit_security_group.this.security_group_id]
}

resource "stackit_server" "this" {
  project_id        = var.stackit_project_id
  name              = var.name
  machine_type      = var.machine_type
  availability_zone = var.availability_zone

  boot_volume = {
    source_type           = "image"
    source_id             = data.stackit_image_v2.runner.image_id
    size                  = var.disk_size_gb
    delete_on_termination = true
  }

  network_interfaces = [stackit_network_interface.this.network_interface_id]

  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    git_url            = var.git_base_url
    registration_token = local.registration_token
    runner_name        = var.name
    runner_labels      = join(",", var.runner_labels)
    runner_version     = var.runner_version
    node_version       = var.node_version
  })
}

resource "terraform_data" "await_registration" {
  triggers_replace = [stackit_server.this.server_id]

  provisioner "local-exec" {
    command = "sh '${path.module}/await-runner-registration.sh' '${var.git_base_url}' '${var.git_organization}' '${var.name}'"

    environment = {
      FORGEJO_API_TOKEN = var.forgejo_api_token
    }
  }
}

moved {
  from = stackit_network.this[0]
  to   = stackit_network.this
}

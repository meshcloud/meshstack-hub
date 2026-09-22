locals {
  registration_token = jsondecode(data.http.registration_token.response_body).token

  create_network = var.network_id == null
  network_id     = local.create_network ? stackit_network.this[0].network_id : var.network_id
}

data "http" "registration_token" {
  url    = "${var.forgejo_base_url}/api/v1/orgs/${var.forgejo_organization}/actions/runners/registration-token"
  method = "GET"
  request_headers = {
    Authorization = "token ${var.forgejo_token}"
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
      error_message = "Could not mint a registration token for org '${var.forgejo_organization}' (HTTP ${self.status_code}). Check the PAT has org-admin rights and that Actions is enabled on the Git instance."
    }
  }
}

resource "tls_private_key" "this" {
  algorithm = "ED25519"
}

resource "stackit_key_pair" "this" {
  name       = var.name
  public_key = chomp(tls_private_key.this.public_key_openssh)
}

resource "stackit_network" "this" {
  count = local.create_network ? 1 : 0

  project_id         = var.stackit_project_id
  name               = var.name
  ipv4_nameservers   = ["9.9.9.9", "149.112.112.112"]
  ipv4_prefix_length = 24
}

resource "stackit_network_interface" "this" {
  project_id = var.stackit_project_id
  network_id = local.network_id
  name       = var.name
}

resource "stackit_public_ip" "this" {
  project_id           = var.stackit_project_id
  network_interface_id = stackit_network_interface.this.network_interface_id
}

resource "stackit_server" "this" {
  project_id        = var.stackit_project_id
  name              = var.name
  machine_type      = var.machine_type
  availability_zone = var.availability_zone
  keypair_name      = stackit_key_pair.this.name

  boot_volume = {
    source_type           = "image"
    source_id             = var.image_id
    size                  = var.disk_size_gb
    delete_on_termination = true
  }

  network_interfaces = [stackit_network_interface.this.network_interface_id]

  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    forgejo_url            = var.forgejo_base_url
    registration_token     = local.registration_token
    runner_name            = var.name
    runner_labels          = join(",", var.runner_labels)
    forgejo_runner_version = var.forgejo_runner_version
  })
}

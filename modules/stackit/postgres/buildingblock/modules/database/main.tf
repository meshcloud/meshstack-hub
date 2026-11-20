data "stackit_postgresflex_instance" "this" {
  project_id  = var.project_id
  instance_id = var.instance_id
}

resource "stackit_postgresflex_user" "this" {
  project_id  = var.project_id
  instance_id = var.instance_id
  username    = var.username
  # `createdb` would let the user add databases next to those of other tenants.
  roles = ["login"]
}

resource "stackit_postgresflex_database" "this" {
  project_id  = var.project_id
  instance_id = var.instance_id
  name        = var.database_name
  owner       = stackit_postgresflex_user.this.username
}

locals {
  host = data.stackit_postgresflex_instance.this.connection_info.write.host
  port = data.stackit_postgresflex_instance.this.connection_info.write.port
}

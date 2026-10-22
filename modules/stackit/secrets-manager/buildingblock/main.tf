module "instance" {
  source = "./modules/secrets-manager-instance"

  release_on_destroy = var.release_on_destroy
  project_id         = var.project_id
  name               = var.instance_name
}

moved {
  from = stackit_secretsmanager_instance.this
  to   = module.instance.stackit_secretsmanager_instance.this
}

import {
  for_each = var.imports != null && !var.release_on_destroy ? toset([var.imports.instance_id]) : toset([])
  to       = module.instance.stackit_secretsmanager_instance.this
  id       = "${var.project_id},${each.value}"
}

import {
  for_each = var.imports != null && var.release_on_destroy ? toset([var.imports.instance_id]) : toset([])
  to       = module.instance.stackit_secretsmanager_instance.released
  id       = "${var.project_id},${each.value}"
}

resource "btp_subaccount_environment_instance" "cloudfoundry" {
  subaccount_id    = var.subaccount_id
  name             = "cf-${var.project_identifier}"
  environment_type = "cloudfoundry"
  service_name     = "cloudfoundry"
  plan_name        = var.cloudfoundry_plan
  parameters = jsonencode({
    instance_name = "cf-${var.project_identifier}"
  })
}

data "btp_subaccount_service_plan" "cf_service_plan" {
  for_each = local.all_cf_services

  subaccount_id = var.subaccount_id
  offering_name = each.value.service_name
  name          = each.value.plan_name
}

resource "btp_subaccount_service_instance" "cf_service" {
  for_each = local.all_cf_services

  subaccount_id  = var.subaccount_id
  name           = each.value.name
  serviceplan_id = data.btp_subaccount_service_plan.cf_service_plan[each.key].id
  parameters     = length(each.value.parameters) > 0 ? jsonencode(each.value.parameters) : null

  lifecycle {
    ignore_changes = [parameters]
  }

  depends_on = [
    btp_subaccount_environment_instance.cloudfoundry
  ]
}

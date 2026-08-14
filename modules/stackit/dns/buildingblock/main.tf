# The zone, its record sets, the delegation record and the DNS credential live in `./zone`, a module
# that declares no provider configuration. This root supplies the `stackit` provider that module
# needs and is what meshStack runs when a team orders the building block.
#
# A composition that owns its own credentials sources `./zone` instead and configures the `stackit`
# provider itself. It has to: this root's provider hardcodes `use_oidc = true` for the workload
# identity federation meshStack runs it with, and a caller cannot override a provider its child
# module configures. The `stackit-landingzone` reference architecture authenticates with a service
# account key and creates the shared zone under `count`, so it calls `./zone`.
#
# Everything this root adds is that provider — see zone/main.tf for the design and the API findings
# behind it.
module "zone" {
  source = "./zone"

  project_id = var.project_id

  create_zone       = var.create_zone
  zone_id           = var.zone_id
  zone_name         = var.zone_name
  zone_display_name = var.zone_display_name
  zone_default_ttl  = var.zone_default_ttl
  contact_email     = var.contact_email
  zone_description  = var.zone_description

  records    = var.records
  wildcard   = var.wildcard
  delegation = var.delegation

  dns_service_account_enabled      = var.dns_service_account_enabled
  dns_service_account_name         = var.dns_service_account_name
  dns_service_account_key_ttl_days = var.dns_service_account_key_ttl_days
}

# The seven resources used to live in this root, so every building block ordered before the move has
# them in its state under the old address. Without these blocks the next run would destroy the zone
# and create a new one, taking every record in it with it, and would mint a fresh DNS key that every
# consumer of the old one would have to be handed again.
#
# Each block moves a whole resource rather than a single instance, which carries every instance key
# across at once — the counts and the `for_each` keys are unchanged by the move.
moved {
  from = stackit_dns_zone.this
  to   = module.zone.stackit_dns_zone.this
}

moved {
  from = stackit_dns_record_set.this
  to   = module.zone.stackit_dns_record_set.this
}

moved {
  from = stackit_dns_record_set.wildcard
  to   = module.zone.stackit_dns_record_set.wildcard
}

moved {
  from = stackit_dns_record_set.delegation
  to   = module.zone.stackit_dns_record_set.delegation
}

moved {
  from = stackit_service_account.dns
  to   = module.zone.stackit_service_account.dns
}

moved {
  from = stackit_authorization_project_role_assignment.dns
  to   = module.zone.stackit_authorization_project_role_assignment.dns
}

moved {
  from = stackit_service_account_key.dns
  to   = module.zone.stackit_service_account_key.dns
}

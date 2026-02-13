data "aws_route53_zone" "zone" {
  name         = var.zone_name
  private_zone = var.private_zone
}

locals {
  # meshStack doesn't support empty strings as inputs right now, so we treat @ (which is common to denote apex records
  # in zonefiles) as a special value to indicate "empty" 
  record_name = var.sub == "@" ? "" : var.sub
}

resource "aws_route53_record" "record" {
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = join(".", compact([local.record_name, data.aws_route53_zone.zone.name]))
  type    = var.type

  alias {
    name                   = var.alias_name
    evaluate_target_health = var.alias_evaluate_target_health
    zone_id                = var.alias_zone_id
  }  
}

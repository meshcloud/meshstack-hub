data "aws_route53_zone" "zone" {
  name         = var.zone_name
  private_zone = var.private_zone
}

locals {
  # meshStack doesn't support empty strings as inputs, so we treat @ (which is common to denote apex records
  # in zonefiles) as a special value to indicate "empty"
  record_name = var.sub == "@" ? "" : var.sub
}

resource "aws_route53_record" "record" {
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = join(".", compact([local.record_name, data.aws_route53_zone.zone.name]))
  type    = var.type
  ttl     = parseint(var.ttl, 10)
  records = [var.record]
}

data "aws_route53_zone" "zone" {
  name         = var.zone_name
  private_zone = var.private_zone
}

resource "aws_route53_record" "record" {
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = "${var.sub}.${data.aws_route53_zone.zone.name}"
  type    = var.type
  ttl     = parseint(var.ttl, 10)
  records = [var.record]
}

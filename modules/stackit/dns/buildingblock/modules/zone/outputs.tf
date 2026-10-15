output "zone" {
  value = one(concat(stackit_dns_zone.this[*], stackit_dns_zone.released[*]))
}

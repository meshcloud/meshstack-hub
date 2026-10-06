output "tenant" {
  value = one(concat(meshstack_tenant.this[*], meshstack_tenant.released[*]))
}

output "name" {
  value = one(concat(kubernetes_namespace_v1.this[*], kubernetes_namespace_v1.released[*])).metadata[0].name
}

output "cluster" {
  value = one(concat(stackit_ske_cluster.this[*], stackit_ske_cluster.released[*]))
}

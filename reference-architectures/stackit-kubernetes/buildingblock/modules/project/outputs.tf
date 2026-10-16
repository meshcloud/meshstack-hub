output "project" {
  value = one(concat(meshstack_project.this[*], meshstack_project.released[*]))
}

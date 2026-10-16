output "instance" {
  value = one(concat(stackit_secretsmanager_instance.this[*], stackit_secretsmanager_instance.released[*]))
}

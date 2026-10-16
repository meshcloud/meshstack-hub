output "instance" {
  value = one(concat(stackit_git.this[*], stackit_git.released[*]))
}

resource "random_id" "suffix" {
  byte_length = 8
}

output "random_suffix" {
  value = random_id.suffix.hex
}

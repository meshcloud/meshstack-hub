output "organizational_unit_id" {
  description = "The ID of the Organizational Unit created in this module."
  value       = aws_organizations_organizational_unit.bedrock.id
}
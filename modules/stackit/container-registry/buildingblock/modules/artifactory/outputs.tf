output "artifactory" {
  value = one(concat(restapi_object.this[*], restapi_object.released[*]))
}

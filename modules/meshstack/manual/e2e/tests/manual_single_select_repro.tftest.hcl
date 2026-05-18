# Reproduces a known provider bug where SINGLE_SELECT and STATIC input types
# in a MANUAL building block definition cause an "unexpected new value" error:
#
#   produced an unexpected new value:
#     .version_spec.outputs: new element "single_select" has appeared.
#     .version_spec.outputs: new element "static_note" has appeared.
#
# The API automatically creates outputs for these input types even though they
# are not declared in the Terraform configuration. The expect_failures assertion
# documents this as a known failure — the test PASSES while the bug is present
# and will FAIL once the provider/API is fixed (at which point expect_failures
# should be removed and a success assertion added instead).

run "reproduces_single_select_provider_bug" {
  module {
    source = "./modules/manual-with-selects"
  }

  expect_failures = [
    meshstack_building_block_definition.this,
  ]
}

# Reproduces a 400 error when a building block instance is created with an
# input key that is not declared on the Building Block Definition version.
#
# Expected provider error:
#   Could not create building block, unexpected error: http error 400,
#   response '{"message":"The following inputs are not known for the Building
#   Block Definition Version <uuid>: single_select(SINGLE_SELECT)",...}'

run "reproduces_unknown_input_400_error" {
  module {
    source = "./modules/manual-with-unknown-input"
  }

  expect_failures = [
    meshstack_building_block_v2.this,
  ]
}

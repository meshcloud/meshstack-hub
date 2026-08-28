# No credentials configured: the building block run authenticates with the ephemeral, workspace-scoped
# API token meshStack injects for the run. That token carries exactly the permissions declared in the
# building block definition's `version_spec.permissions` — APIKEY_SAVE to mint the key, plus every
# permission the key itself may be granted, so any user-selected subset can be issued.
provider "meshstack" {
}

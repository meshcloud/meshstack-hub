# Self-configuring from the MESHSTACK_* environment inputs the definition passes, so the credential
# is not a module input and cannot leak into a plan, an output or this module's state.
provider "meshstack" {}

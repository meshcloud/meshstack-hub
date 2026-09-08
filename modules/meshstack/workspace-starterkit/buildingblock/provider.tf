# Self-configuring: the definition passes the backplane's admin-scoped API key as the
# MESHSTACK_API_KEY / MESHSTACK_API_SECRET environment inputs, and every building block run already
# has MESHSTACK_ENDPOINT in its environment. Nothing here is a module input, so nothing about the
# credential can leak into a plan, an output or the state this module writes.
provider "meshstack" {}

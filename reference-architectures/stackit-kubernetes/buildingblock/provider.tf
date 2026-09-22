# The meshstack provider is configured by the meshStack runtime at order time (mesh http backend), so
# it is intentionally not declared here.
#
# This architecture declares no STACKIT provider: every STACKIT resource is created by a child
# building block that authenticates via WIF as the service account ordered in main.tf.

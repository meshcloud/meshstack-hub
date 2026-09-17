# The meshstack provider is configured by the meshStack runtime at order time (mesh http backend), so
# it is intentionally not declared here.
#
# This architecture creates no STACKIT resources directly — it only orders meshStack building blocks
# (service account, cluster, platform services) and registers the meshStack SKE platform. The real
# STACKIT work runs inside those child building blocks, which authenticate as the runtime service
# account the STACKIT Service Account building block mints. So no stackit/restapi provider is needed.

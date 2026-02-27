---
name: STACKIT SKE Starterkit
supportedPlatforms:
  - stackit
description: One-click dev/prod environment with STACKIT Git repository and SKE Kubernetes namespaces.
---

# STACKIT SKE Starterkit

This building block creates a complete dev/prod environment on STACKIT Kubernetes Engine (SKE),
including a Git repository on STACKIT Git and dedicated Kubernetes namespaces.

## Resources Created

- 2 meshStack projects (dev + prod)
- 2 SKE tenants (Kubernetes namespaces via meshStack replicator)
- 1 STACKIT Git repository (Forgejo/Gitea)
- Project Admin bindings for the creator

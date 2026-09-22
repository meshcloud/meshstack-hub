# STACKIT Container Registry — Backplane

Creates the automation identity the **STACKIT Container Registry** building block deploys as: a
STACKIT service account in the foundation project, a federated identity provider trusting the
building block definition's meshStack WIF subject, and folder-scoped role assignments.

## Roles

| Role | Why |
|---|---|
| `editor` | Narrowest folder role carrying `service-enablement.service-state.edit`. `cloud.stackit.container-registry` is DISABLED by default on every project measured, so the service has to be switched on before a registry can be created in it. |
| `container-registry.admin` | Carries `container-registry.project.create`. |

Roles are assigned on the landing-zone folder, not on a project: the project the registry is created
in is provisioned at order time inside that folder, so a folder-scoped grant is inherited down to it.

## What these roles do not buy

Neither role opens the Harbor API. No STACKIT IAM role does — tested with a service account holding
`container-registry-manager`, `container-registry.project.manager`, `container-registry.admin`,
`container-registry.artifactory.admin` and `container-registry.artifactory.maintainer` together:
`POST /api/v2.0/robots` answered `401`, not `403`, so Harbor did not recognise the principal at all.

Harbor access comes from linking a robot account to a STACKIT service account in the portal. See the
building block README.

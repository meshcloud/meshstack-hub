---
description: GCP backplane conventions for meshstack-hub modules under modules/gcp/. Covers the workload identity federation pattern (pool + provider + service account), project API enablement with disable_on_destroy = false, required permissions for the applying identity, the workload identity pool soft-delete constraint, and the GCP backplane checklist.
---

# GCP Backplane Conventions

A GCP backplane prepares a GCP project for a building block: it **enables the project APIs** the
building block depends on, creates the **service account** the building block runs as, grants that
service account its roles, and — on the workload identity path — creates the **workload identity
pool and provider** that let the meshStack building block runner federate into it.

> **Status: partly unsettled.** Only two GCP backplanes exist today —
> `modules/gcp/storage-bucket/backplane` (workload identity federation, with a service account key
> fallback) and `modules/gcp/budget-alert/backplane` (service account key only). Where they agree,
> this document states a convention. Where they disagree it says so explicitly rather than
> retrofitting a rule onto one of them.

## Authentication: prefer workload identity federation

New GCP backplanes should use **workload identity federation**, matching Azure (UAMI + federated
credential) and STACKIT (service account + federated identity provider). Service account keys are
long-lived secrets that have to be rotated, revoked and protected.

`modules/gcp/budget-alert/backplane` still issues a `google_service_account_key`. Treat that as
legacy, not as the pattern to copy.

<!-- The WIF pattern below is implemented in modules/gcp/storage-bucket/backplane. -->
## Implementation Pattern (workload identity federation)

```hcl
resource "google_iam_workload_identity_pool" "meshstack" {
  project                   = var.project_id
  workload_identity_pool_id = var.workload_identity_federation.workload_identity_pool_identifier
}

resource "google_iam_workload_identity_pool_provider" "meshstack" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.meshstack.workload_identity_pool_id
  workload_identity_pool_provider_id = var.workload_identity_federation.workload_identity_pool_identifier

  oidc {
    issuer_uri        = var.workload_identity_federation.issuer
    allowed_audiences = [var.workload_identity_federation.audience]
  }

  attribute_mapping = {
    "google.subject" = "assertion.sub"
  }

  # Restrict token acceptance to the configured subjects.
  attribute_condition = join(" || ", [
    for subject in var.workload_identity_federation.subjects :
    "google.subject.startsWith('${subject}')"
  ])
}

resource "google_service_account" "buildingblock" {
  project    = var.project_id # always explicit — the module declares no provider block
  account_id = var.service_account_id
}

resource "google_service_account_iam_binding" "workload_identity" {
  service_account_id = google_service_account.buildingblock.name
  role               = "roles/iam.workloadIdentityUser"
  members            = ["principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.meshstack.name}/*"]
}

resource "google_project_iam_member" "buildingblock" {
  project = var.project_id
  role    = "<the one role the building block needs>"
  member  = "serviceAccount:${google_service_account.buildingblock.email}"
}
```

`issuer`, `audience` and `subjects` must always come from `data.meshstack_integrations` in
`meshstack_integration.tf` — never hardcoded. See the AWS and Azure references for the shared
subject-derivation idiom.

The backplane's `credentials_json` output is then an
[external account](https://cloud.google.com/iam/docs/workload-identity-federation) credential
document (`type = "external_account"`) pointing at the runner's token file, passed to the building
block as a `FILE` input with `GOOGLE_APPLICATION_CREDENTIALS` set to its path.

## Project API enablement

**A GCP backplane must enable the APIs its building block depends on.** A project that has never
used an API answers every call with `SERVICE_DISABLED`, and enabling it is exactly the cloud-side
preparation a backplane exists to do — not something to leave to a landing zone or a runbook.

Enable everything **the backplane provisions** and everything **the building block needs at run
time**:

```hcl
resource "google_project_service" "required" {
  for_each = toset([
    "iam.googleapis.com",                  # service accounts, workload identity pools + providers
    "cloudresourcemanager.googleapis.com", # project-level IAM bindings
    "sts.googleapis.com",                  # WIF token exchange at building block run time
    "iamcredentials.googleapis.com",       # service account impersonation at run time
    "<the API the building block itself calls>",
  ])

  project                    = var.project_id
  service                    = each.value
  disable_on_destroy         = false
  disable_dependent_services = false
}
```

**`disable_on_destroy = false` is mandatory.** It is not the provider default, so it must be set
explicitly. A backplane is not the exclusive owner of its project and can be short-lived — an e2e
test provisions and destroys one per run — so a teardown that switched project-wide APIs off would
break every other tenant of that project.

`serviceusage.googleapis.com` itself is not in the list: it is enabled on every project by default
and is the API used to do the enabling.

Resources that need an API must **`depends_on` the enablement**, because nothing in them references
it:

```hcl
resource "google_iam_workload_identity_pool" "meshstack" {
  depends_on = [google_project_service.required]
  # ...
}
```

## Required permissions for the applying identity

Document these in `backplane/README.md`. The identity that applies the backplane — a platform
engineer or a CI principal — needs, on the target project:

| Role | For |
|---|---|
| `roles/serviceusage.serviceUsageAdmin` | `google_project_service` |
| `roles/iam.workloadIdentityPoolAdmin` | `google_iam_workload_identity_pool` / `_provider` |
| `roles/iam.serviceAccountAdmin` | `google_service_account` and its IAM policy |
| `roles/resourcemanager.projectIamAdmin` | `google_project_iam_member` |

`serviceusage.serviceUsageAdmin` cannot be bootstrapped by the module — enabling a service already
requires it — so it must be granted out of band before the first apply.

Do **not** grant `roles/serviceusage.serviceUsageAdmin` to the *building block's* service account
unless the building block itself enables services. `modules/gcp/budget-alert/backplane` does grant
it, and its building block never calls serviceusage, so that grant is dead privilege rather than a
pattern to copy.

## Workload identity pools are not immediately reusable

GCP **soft-deletes** workload identity pools and providers and keeps them for ~30 days, during which
their identifiers cannot be claimed again — the Terraform provider does not undelete them. So:

- Expose the pool identifier as an input rather than hardcoding it, so a caller that has to recreate
  a backplane can pick a fresh one.
- Callers that create and destroy a backplane repeatedly (e2e tests) must derive a **unique
  identifier per run**, and should keep in mind that the soft-deleted pools accumulate against the
  project's workload identity pool limit.
- Note the constraint in `backplane/README.md`.

## No provider block in the backplane

`backplane/` must not contain a `provider "google"` block; the caller supplies the provider. A module
whose tree contains a provider configuration is a *legacy module* that callers may not wrap with
`count`, `for_each` or `depends_on` — which an e2e root needs in order to gate the
build-from-source path. Because of that, **every resource sets `project = var.project_id`
explicitly** rather than inheriting a provider-level default project.

## Backplane Variables (GCP)

Naming is **not yet consistent** across the two existing modules: `storage-bucket` uses
`project_id`, `budget-alert` uses `backplane_project_id`. Prefer `project_id` for new modules.

```hcl
variable "project_id" {
  type        = string
  nullable    = false
  description = "GCP project ID the building block provisions into."
}

variable "service_account_id" {
  type        = string
  description = "Account ID of the service account the building block runs as."
  default     = "buildingblock-<service>-sa"
}

variable "workload_identity_federation" {
  type = object({
    workload_identity_pool_identifier = string
    audience                          = string
    issuer                            = string
    subjects                          = list(string)
    subject_token_file_path           = string
  })
  default     = null # null falls back to a service account key
  description = "Workload identity federation settings sourced from data.meshstack_integrations."
}
```

## Backplane Outputs (GCP)

```hcl
output "credentials_json" {
  sensitive = true
  value     = <external_account document, or the decoded key on the legacy path>
}

output "service_account_email" {
  value = google_service_account.buildingblock.email
}
```

Both existing modules expose these two. Do not add a `documentation_md` output — see CLAUDE.md.

## What to Avoid

- ❌ `provider "google"` block inside `backplane/` — makes the module unusable with `count`/`depends_on`
- ❌ Omitting `project` on a resource and relying on a provider default project
- ❌ `google_project_service` without `disable_on_destroy = false`
- ❌ `google_service_account_key` for new modules — use workload identity federation
- ❌ Hardcoded `issuer`, `audience` or `subjects` — source them from `data.meshstack_integrations`
- ❌ Hardcoded workload identity pool identifier — soft-delete makes it unreusable for ~30 days
- ❌ Granting the building block's service account `roles/serviceusage.serviceUsageAdmin` when the
  building block does not enable services

## Checklist for GCP Backplanes

- [ ] No `provider "google"` block in `backplane/`
- [ ] Every resource sets `project = var.project_id` explicitly
- [ ] `google_project_service` covers the backplane's own APIs *and* the building block's run-time APIs
- [ ] `google_project_service` sets `disable_on_destroy = false`
- [ ] Resources needing an API carry `depends_on = [google_project_service.required]`
- [ ] Workload identity pool + provider present (not a `google_service_account_key`) for new modules
- [ ] `attribute_condition` restricts `google.subject` to the configured subjects
- [ ] `google_service_account_iam_binding` grants `roles/iam.workloadIdentityUser` on the pool
- [ ] Workload identity pool identifier is an input, not a hardcoded literal
- [ ] `credentials_json` (sensitive) and `service_account_email` outputs present
- [ ] `backplane/README.md` documents the four required roles for the applying identity, the APIs
      enabled, and the pool soft-delete constraint
- [ ] `meshstack_integration.tf` sources issuer/audience/subject from `data.meshstack_integrations`

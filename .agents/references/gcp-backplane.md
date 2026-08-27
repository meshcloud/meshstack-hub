---
description: GCP backplane identity conventions for meshstack-hub modules under modules/gcp/. Covers the mandatory workload identity federation pattern (pool + provider + service account), why there is no service account key path, project API enablement with disable_on_destroy = false, required permissions for the applying identity, the workload identity pool soft-delete constraint, and the GCP backplane checklist.
---

# GCP Backplane Conventions

A GCP backplane prepares a GCP project for a building block: it **enables the project APIs** the
building block depends on, creates the **service account** the building block runs as, grants that
service account its roles, and — on the workload identity path — creates the **workload identity
pool and provider** that let the meshStack building block runner federate into it.

## Authentication: workload identity federation, and nothing else

A GCP backplane **must** authenticate the building block by **workload identity federation**. This
matches what the other providers already require of their backplanes — Azure a UAMI with a federated
identity credential and no client secrets, STACKIT a service account with a federated identity
provider and no `stackit_service_account_key` — and it is enforced the same way, by scorecard checks
rather than by review.

`workload_identity_federation` is therefore a **required, non-nullable** input. Do not make it
optional with a `google_service_account_key` fallback:

- A key is a long-lived secret that has to be rotated, revoked, protected in transit, and kept out
  of state dumps and logs. A federated credential is a pointer to the runner's own token file and
  carries nothing worth stealing.
- The key path costs the *applying* identity `roles/iam.serviceAccountKeyAdmin` on top of every
  other role, because `roles/iam.serviceAccountAdmin` does **not** include
  `iam.serviceAccountKeys.create`. Federation needs strictly fewer privileges.
- Supporting both doubles the module: a `count` on every federation resource, a conditional
  `credentials_json`, and two sets of required roles to document.

This is also what the platform tier next door already asks for: `modules/gcp/meshstack_integration.tf`
configures the GCP meshPlatform with `service_account_keys = false # Use only workload identity
federation`. A backplane that mints a key contradicts the platform it runs on.

<!-- scorecard-checks: gcp_uses_wif, gcp_wif_attribute_condition, gcp_workload_identity_user_binding, gcp_no_sa_key -->
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

### Why GCP WIF subjects stop at the workspace

`modules/azure/`, `modules/aws/` and `modules/stackit/` append the building block definition uuid to
the subject; GCP deliberately does not because this creates a dependency cycle of the following form

```hcl
# --- backplane module ---
resource "google_iam_workload_identity_pool_provider" "meshstack" {
  # trust condition wants to name the specific BBD so that only a single BBD can assume the role
  attribute_condition = "google.subject.startsWith('...buildingblockdefinition.${var.bbd_uuid}')"
  ...
}

output "credentials_json" {
  # audience must reference *this* pool provider's resource name
  value = jsonencode({
    audience = "//iam.googleapis.com/${google_iam_workload_identity_pool_provider.meshstack.name}"
    ...
  })
}

# --- root module ---
resource "meshstack_building_block_definition" "gcp_storage_bucket" {
  # the BBD needs the backplane's credentials as a static input...
  spec = {
    inputs = {
      secret_value = "data:application/json;base64,${base64encode(module.backplane.credentials_json)}"
    }
  }
}

module "backplane" {
  source = "./backplane"
  # ...but the backplane needs the BBD's uuid to scope the trust condition, we now have a dependency cycle
  bbd_uuid = meshstack_building_block_definition.gcp_storage_bucket.id
}
```

The current workaround for this problem is to use an `attribute_condition` that does not pin the BBD uuid.
A `startsWith` admits any building block definition owned by the same platform team workspace, so all of
them share the backplane's federated identity — but authoring a definition in that workspace is
already a privileged action, and in practice it coincides with being able to change the backplane
itself. The residual cost is audit attribution: Cloud Audit Logs cannot tell which definition acted.
Monitor https://feedback.meshcloud.io/feature-requests/p/introduce-building-block-definition-version-spec-resource-in-meshstack-terraform
for progress on this matter.

<!-- scorecard-checks: gcp_project_service_disable_on_destroy -->
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

`serviceusage.googleapis.com` itself cannot be in the list — it is the API that does the enabling,
so `google_project_service` cannot bootstrap it. Do not assume it is already on: a project where it
is disabled fails on the *read*, before any enable is attempted, with

```
Error: Error when reading or editing Project Service : ... Failed to list enabled services
for project <project>: googleapi: Error 403: Service Usage API has not been used in project
<number> before or it is disabled.  ...  "reason": "SERVICE_DISABLED"
```

Enabling it is a one-time out-of-band step for the project owner
(`gcloud services enable serviceusage.googleapis.com --project <project>`), and
`backplane/README.md` should say so.

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
requires it — so it must be granted out of band before the first apply, as must the Service Usage
API itself.

Do **not** grant `roles/serviceusage.serviceUsageAdmin` to the *building block's* service account
unless the building block itself enables services. A building block that never calls serviceusage
and holds the role anyway is dead privilege: it lets a tenant-facing identity enable arbitrary APIs
on the project for no benefit.

`roles/iam.serviceAccountKeyAdmin` is deliberately absent from the table — nothing in a GCP backplane
mints a key, and the role exists only on the path this document forbids.

<!-- scorecard-checks: gcp_iam_propagation_wait -->
## IAM is eventually consistent — make the credentials wait

A backplane that grants a role and publishes credentials in the same apply is publishing credentials
that do not work yet. GCP IAM propagation is slow enough to matter: Google's workload identity
federation guidance is to allow **two to seven minutes** after adding a
`roles/iam.workloadIdentityUser` binding before retrying a denied impersonation.

The failure is easy to misread, because the token exchange succeeds and only the impersonation is
refused — which looks like a misconfigured pool rather than a timing problem:

```
Error: Post "https://storage.googleapis.com/storage/v1/b?...&project=...":
oauth2/google: status code 403: Permission 'iam.serviceAccounts.getAccessToken' denied on
resource (or it may not exist). ... "reason": "IAM_PERMISSION_DENIED"
```

If you see that, verify the binding before assuming it is wrong — reading the live policy takes one
call and rules out the whole structural half of the search space:

```sh
gcloud iam service-accounts get-iam-policy <sa-email> --project <project>
```

Express the wait so consumers inherit it, rather than leaving it to each caller:

```hcl
resource "time_sleep" "wait_for_iam" {
  depends_on      = [google_service_account_iam_binding.workload_identity, google_project_iam_member.buildingblock]
  create_duration = "${var.iam_propagation_delay_seconds}s"
}

output "credentials_json" {
  depends_on = [time_sleep.wait_for_iam] # credentials are not usable until the grants have propagated
  sensitive  = true
  value      = ...
}
```

Putting the `depends_on` on the **output** is what makes this work without cooperation: a consumer
that builds a building block definition from `credentials_json` and orders a building block seconds
later is ordered after the wait automatically. This matters for compositions and reference
architectures, which really do apply a backplane and order building blocks in one run.

Follow the existing hub convention for the delay itself: a `*_delay_seconds` variable with a
default, as `modules/azure/spoke-network/buildingblock` does for Azure role assignments.

## Workload identity pools are not immediately reusable

GCP **soft-deletes** workload identity pools and providers and keeps them for ~30 days, during which
their identifiers cannot be claimed again — the Terraform provider does not undelete them. So:

- Expose the pool identifier as an input rather than hardcoding it, so a caller that has to recreate
  a backplane can pick a fresh one.
- Callers that create and destroy a backplane repeatedly (e2e tests) must derive a **unique
  identifier per run**, and should keep in mind that the soft-deleted pools accumulate against the
  project's workload identity pool limit.
- Note the constraint in `backplane/README.md`.

<!-- scorecard-checks: gcp_no_provider_block -->
## No provider block in the backplane

`backplane/` must not contain a `provider "google"` block; the caller supplies the provider. A module
whose tree contains a provider configuration is a *legacy module* that callers may not wrap with
`count`, `for_each` or `depends_on` — which an e2e root needs in order to gate the
build-from-source path. Because of that, **every resource sets `project = var.project_id`
explicitly** rather than inheriting a provider-level default project.

<!-- scorecard-checks: gcp_wif_nonnullable -->
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
  nullable    = false # required: there is no service account key fallback
  description = "Workload identity federation settings sourced from data.meshstack_integrations."
}
```

<!-- scorecard-checks: gcp_credentials_output -->
## Backplane Outputs (GCP)

```hcl
output "credentials_json" {
  depends_on = [time_sleep.wait_for_iam]
  sensitive  = true
  value      = <the external_account document>
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
- ❌ `google_service_account_key` — use workload identity federation
- ❌ Conditional WIF-vs-key logic: a nullable `workload_identity_federation` and a `count` on every
  federation resource
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
- [ ] Workload identity pool + provider present
- [ ] No `google_service_account_key` anywhere in `backplane/`
- [ ] `workload_identity_federation` is `nullable = false` — no key fallback, no `default = null`
- [ ] `attribute_condition` restricts `google.subject` to the configured subjects
- [ ] `google_service_account_iam_binding` grants `roles/iam.workloadIdentityUser` on the pool
- [ ] Workload identity pool identifier is an input, not a hardcoded literal
- [ ] A `time_sleep` absorbs IAM propagation and the `credentials_json` output `depends_on` it
- [ ] `credentials_json` (sensitive) and `service_account_email` outputs present
- [ ] `backplane/README.md` documents the four required roles for the applying identity, the APIs
      enabled, and the pool soft-delete constraint
- [ ] `meshstack_integration.tf` sources issuer/audience/subject from `data.meshstack_integrations`

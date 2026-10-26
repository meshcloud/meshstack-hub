# GKE Temporary Namespace Access Backplane

This module prepares a GCP project and its GKE cluster for the GKE Temporary Namespace Access
building block. The building block grants a developer time-limited access to one namespace using
their Google account. It makes two grants:

- GCP: `roles/container.clusterViewer` on the project, with an IAM condition that expires. This is
  required because GKE refuses authentication without `container.clusters.get`.
- GKE: A RoleBinding to `cluster_role` (default `view`) in the chosen namespace. It sets what the
  building block user can do in the namespace.

The backplane enables the APIs, creates a service account for the building block with workload
identity federation, and gives it just enough rights to make those two grants. It also runs a
CronJob that removes expired RoleBindings.

## How access expires

The conditional IAM grant expires at the requested time. If another IAM grant still allows the
developer to authenticate, the cleanup CronJob removes this building block's RoleBinding on its
next successful run. It runs every five minutes. Independently granted access is unaffected.

For IAM expiry to prevent cluster authentication, developers must not hold `container.clusters.get`
through another grant. Check effective permissions on the project, including roles inherited from a
folder or the organization.

## Building block service account permissions

| Where | Grant | Why |
|---|---|---|
| Project | `roles/container.clusterViewer` | authenticate to the cluster |
| Project | `roles/resourcemanager.projectIamAdmin`, limited by an IAM condition to grants of `roles/container.clusterViewer` | grant developers time-limited cluster access |
| Cluster | get, list, create, update, patch and delete RoleBindings; `bind` on `cluster_role` only | grant developers `cluster_role` in a namespace |

The IAM condition restricts which role the service account can grant, but does not require those
grants to expire. The service account could therefore grant `roles/container.clusterViewer` without
a time limit. That role alone does not authorize access to resources inside a namespace.

## Forbidden namespaces

Developers can request any existing namespace that does not match the denylist. The cleanup
namespace (`cleanup_namespace`) is always blocked. A trailing `*` matches a prefix.

| `forbidden_namespaces` | Blocked namespaces |
|---|---|
| Omitted | `kube-*`, `gke-*`, `gmp-*` and the cleanup namespace |
| `[]` | Only the cleanup namespace |
| Explicit list | The supplied names or patterns and the cleanup namespace |

An explicit list replaces the default system-namespace patterns. For example, this blocks
`production`, namespaces starting with `payments-`, and the cleanup namespace:

```hcl
forbidden_namespaces = ["production", "payments-*"]
```

To keep any default system-namespace patterns alongside custom ones, include them explicitly.

Add new sensitive namespaces that are not covered by an existing prefix before creating them.

## Admission policy

RBAC can't restrict RoleBindings by label or by subject. A ValidatingAdmissionPolicy restricts
create, update and delete requests from the building block's Google service account and the
cleanup job's Kubernetes ServiceAccount:

- Creating or updating RoleBindings in forbidden namespaces is denied. Deleting managed bindings
  remains allowed so previously granted access can still be revoked.
- Updates and deletions are allowed only for RoleBindings already labelled `<binding_label>=true`.
  Other RoleBindings cannot be modified or deleted by these identities, but remain readable
  through their RBAC permissions.
- Created or updated RoleBindings must have the label `<binding_label>=true`, an annotation with
  the key `expiry_annotation`, only `User` subjects whose names do not start with `system:`, and a
  reference to the ClusterRole `cluster_role`. This excludes groups such as
  `system:authenticated`, the `system:anonymous` user, and ServiceAccounts.

ValidatingAdmissionPolicy is generally available in Kubernetes 1.30 and later, so the cluster must
run GKE 1.30 or later.

## Cleanup CronJob

A CronJob in `cleanup_namespace` (default `gke-temporary-access`) runs every five minutes. It selects
RoleBindings labelled `<binding_label>=true` and deletes those whose expiry timestamp, stored under
the annotation key `expiry_annotation`, is in the past. The building block sets both metadata entries
on every RoleBinding it creates.

The job's Kubernetes ServiceAccount may list RoleBindings cluster-wide, but the admission policy
limits deletion to managed bindings. The script needs `bash`, `date` and `kubectl` and runs on
`cleanup_image` (default `alpine/k8s:1.37.1`).

## Permissions

The identity that applies this module needs the following on `var.project_id`:

| Role | What it is for |
|---|---|
| `roles/serviceusage.serviceUsageAdmin` | enable the project APIs listed below |
| `roles/iam.workloadIdentityPoolAdmin` | create the workload identity pool and its OIDC provider |
| `roles/iam.serviceAccountAdmin` | create the building block service account and set its IAM policy |
| `roles/resourcemanager.projectIamAdmin` | grant that service account its project roles |
| `roles/container.clusterViewer` | authenticate to the cluster |

It also needs RBAC rights in the cluster to create the cleanup namespace and CronJob, ClusterRoles,
ClusterRoleBindings that grant `bind` on `cluster_role`, and the ValidatingAdmissionPolicy, which in
practice means `cluster-admin`. The cluster must be reachable while planning, because the policy is
a `kubernetes_manifest`.

`serviceusage.serviceUsageAdmin` and the Service Usage API itself must be in place before the first
apply:

```sh
gcloud services enable serviceusage.googleapis.com --project <project>
```

### APIs enabled

`iam`, `cloudresourcemanager`, `sts`, `iamcredentials` and `container`, all with
`disable_on_destroy = false`.

## Workload identity pools are not immediately reusable

GCP soft-deletes workload identity pools and providers for ~30 days, during which their identifiers
can't be claimed again. Pick a fresh `workload_identity_pool_identifier` when you recreate the
backplane.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 7.0, < 8.0.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 3.0.0, < 4.0.0 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.9, < 1.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_iam_workload_identity_pool.meshstack](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool) | resource |
| [google_iam_workload_identity_pool_provider.meshstack](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool_provider) | resource |
| [google_project_iam_member.cluster_viewer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.grant_cluster_viewer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_service.required](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_service_account.buildingblock](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account_iam_binding.workload_identity](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_binding) | resource |
| [kubernetes_cluster_role_binding_v1.cleanup](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_binding_v1) | resource |
| [kubernetes_cluster_role_binding_v1.grant_access](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_binding_v1) | resource |
| [kubernetes_cluster_role_v1.cleanup](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_v1) | resource |
| [kubernetes_cluster_role_v1.grant_access](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_v1) | resource |
| [kubernetes_cron_job_v1.cleanup](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cron_job_v1) | resource |
| [kubernetes_manifest.rolebinding_policy](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_manifest.rolebinding_policy_binding](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_namespace_v1.cleanup](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |
| [kubernetes_service_account_v1.cleanup](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account_v1) | resource |
| [google_project.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cleanup_image"></a> [cleanup\_image](#input\_cleanup\_image) | Container image used by the cleanup CronJob. It must include `bash`, `date` and `kubectl`. | `string` | `"alpine/k8s:1.37.1"` | no |
| <a name="input_cleanup_namespace"></a> [cleanup\_namespace](#input\_cleanup\_namespace) | Namespace created for the CronJob that removes expired RoleBindings. | `string` | `"gke-temporary-access"` | no |
| <a name="input_cluster_role"></a> [cluster\_role](#input\_cluster\_role) | Existing ClusterRole assigned to users by the building block. | `string` | `"view"` | no |
| <a name="input_forbidden_namespaces"></a> [forbidden\_namespaces](#input\_forbidden\_namespaces) | Namespace denylist. Defaults to `kube-*`, `gke-*` and `gmp-*`. An explicit list replaces these defaults. The cleanup namespace is always blocked, even with `[]`. A trailing `*` matches a prefix. | `list(string)` | <pre>[<br/>  "kube-*",<br/>  "gke-*",<br/>  "gmp-*"<br/>]</pre> | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | GCP project ID that contains the GKE cluster. | `string` | n/a | yes |
| <a name="input_service_account_id"></a> [service\_account\_id](#input\_service\_account\_id) | Account ID of the building block's Google service account. It also prefixes the in-cluster ClusterRoles and admission policy, so it must be unique per project and per cluster. | `string` | `"buildingblock-gke-access-sa"` | no |
| <a name="input_workload_identity_federation"></a> [workload\_identity\_federation](#input\_workload\_identity\_federation) | Workload identity federation settings describing the building block runner. | <pre>object({<br/>    workload_identity_pool_identifier = string<br/>    subject_token_file_path           = string<br/>  })</pre> | n/a | yes |
| <a name="input_workload_identity_federation_trust"></a> [workload\_identity\_federation\_trust](#input\_workload\_identity\_federation\_trust) | The building block runner's OIDC issuer and audience, and the subject claims it accepts. | <pre>object({<br/>    issuer   = string<br/>    audience = string<br/>    subjects = list(string)<br/>  })</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_binding_label"></a> [binding\_label](#output\_binding\_label) | Label key used to identify managed RoleBindings. The building block sets its value to `true`. |
| <a name="output_cluster_role"></a> [cluster\_role](#output\_cluster\_role) | ClusterRole the building block binds developers to. |
| <a name="output_credentials_json"></a> [credentials\_json](#output\_credentials\_json) | Credentials for the building block's service account. Points the runner at its own OIDC token file, which it exchanges for a short-lived access token. |
| <a name="output_expiry_annotation"></a> [expiry\_annotation](#output\_expiry\_annotation) | Annotation key used to store the RoleBinding's expiry timestamp in RFC 3339 format (UTC, `YYYY-MM-DDTHH:MM:SSZ`). |
| <a name="output_forbidden_namespaces"></a> [forbidden\_namespaces](#output\_forbidden\_namespaces) | Namespaces the building block can't grant access to. A trailing `*` matches a prefix. |
| <a name="output_service_account_email"></a> [service\_account\_email](#output\_service\_account\_email) | Email of the service account the building block runs as. |
<!-- END_TF_DOCS -->

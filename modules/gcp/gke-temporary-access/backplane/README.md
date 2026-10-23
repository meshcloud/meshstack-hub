# GKE Temporary Access Backplane

This module prepares a GCP project and its GKE cluster for the GKE Temporary Access building block.
The building block gives a user time-limited access to one namespace. It does that with two grants
to the developer's Google identity:

- `roles/container.clusterViewer` on the project, with an IAM condition that expires. GKE refuses
  authentication without `container.clusters.get`.
- A RoleBinding to `cluster_role` (default `view`) in the chosen namespace. It sets what the
  developer can do.

The backplane enables the APIs, creates a service account for the building block with workload
identity federation, and gives it just enough rights to make those two grants. It also runs a
CronJob that removes expired RoleBindings.

## Prerequisite: no permanent `container.clusters.get`

The expiry only works if developers can't authenticate to the cluster any other way. Developers must
not permanently hold a role that contains `container.clusters.get` on the project, directly or
inherited from a folder or the organization. Basic roles (`roles/viewer`, `roles/editor`,
`roles/owner`) and all `roles/container.*` roles contain it.

`roles/logging.viewer` (part of `roles/viewer`) exposes container logs of every namespace in Cloud
Logging. Remove it as well if the namespaces' logs are sensitive.

## What the building block's service account may do

| Where | Grant | Why |
|---|---|---|
| Project | `roles/container.clusterViewer` | authenticate to the cluster |
| Project | `roles/resourcemanager.projectIamAdmin`, limited by an IAM condition to grants of `roles/container.clusterViewer` | grant developers time-limited cluster access |
| Each namespace in `namespaces` | create and delete RoleBindings, `bind` on `cluster_role` only | grant developers `cluster_role` in that namespace |

The IAM condition can't force an expiry on the grants the service account makes. So it can
theoretically grant `roles/container.clusterViewer` without a time limit. That grant does not
give access to any cluster resources though.

## Cleanup CronJob

A CronJob in `cleanup_namespace` (default `gke-temporary-access`) runs every five minutes and
deletes each RoleBinding in `namespaces` with the `binding_label` if `expiry_annotation` is in
the past. The building block sets both on every RoleBinding it creates.

Its ServiceAccount may only list and delete RoleBindings in `namespaces`. The script needs `bash`,
`date` and `kubectl` and runs on `cleanup_image` (defaults to `alpine/k8s`).

## Permissions

The identity that applies this module needs the following on `var.project_id`:

| Role | What it is for |
|---|---|
| `roles/serviceusage.serviceUsageAdmin` | enable the project APIs listed below |
| `roles/iam.workloadIdentityPoolAdmin` | create the workload identity pool and its OIDC provider |
| `roles/iam.serviceAccountAdmin` | create the building block service account and set its IAM policy |
| `roles/resourcemanager.projectIamAdmin` | grant that service account its project roles |

It also needs RBAC rights in the cluster to create the cleanup namespace and CronJob, ClusterRoles,
and RoleBindings that grant `bind` on `cluster_role`, which in practice means `cluster-admin`.

`serviceusage.serviceUsageAdmin` and the Service Usage API itself must be in place before the first
apply:

```sh
gcloud services enable serviceusage.googleapis.com --project <project>
```

### APIs enabled

`iam`, `cloudresourcemanager`, `sts`, `iamcredentials` and `container`, all with
`disable_on_destroy = false`.

## IAM propagation

`credentials_json` waits on `time_sleep.wait_for_iam` (180 s by default) because GCP IAM is
eventually consistent. Tune it with `iam_propagation_delay_seconds`.

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
| [kubernetes_cluster_role_v1.cleanup](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_v1) | resource |
| [kubernetes_cluster_role_v1.grant_access](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_v1) | resource |
| [kubernetes_cron_job_v1.cleanup](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cron_job_v1) | resource |
| [kubernetes_namespace_v1.cleanup](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |
| [kubernetes_role_binding_v1.cleanup](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/role_binding_v1) | resource |
| [kubernetes_role_binding_v1.grant_access](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/role_binding_v1) | resource |
| [kubernetes_service_account_v1.cleanup](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account_v1) | resource |
| [time_sleep.wait_for_iam](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [google_project.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cleanup_image"></a> [cleanup\_image](#input\_cleanup\_image) | Image of the cleanup CronJob. It needs bash, date and kubectl. | `string` | `"alpine/k8s:1.37.1"` | no |
| <a name="input_cleanup_namespace"></a> [cleanup\_namespace](#input\_cleanup\_namespace) | Namespace the backplane creates for the CronJob that removes expired RoleBindings. | `string` | `"gke-temporary-access"` | no |
| <a name="input_cluster_role"></a> [cluster\_role](#input\_cluster\_role) | Existing ClusterRole the building block binds developers to in the chosen namespace. | `string` | `"view"` | no |
| <a name="input_iam_propagation_delay_seconds"></a> [iam\_propagation\_delay\_seconds](#input\_iam\_propagation\_delay\_seconds) | Seconds to wait after granting the building block's IAM roles before publishing its credentials. GCP IAM is eventually consistent, and Google's guidance is to allow two to seven minutes before retrying a denied impersonation. Set to 0 if the backplane is always provisioned well before any building block run. | `number` | `180` | no |
| <a name="input_namespaces"></a> [namespaces](#input\_namespaces) | Namespaces developers can request temporary access to. They must already exist in the cluster. | `set(string)` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | GCP project ID that contains the GKE cluster. | `string` | n/a | yes |
| <a name="input_service_account_id"></a> [service\_account\_id](#input\_service\_account\_id) | Account ID of the service account the building block runs as. Also prefixes the in-cluster ClusterRole, so it must be unique per cluster. | `string` | `"buildingblock-gke-access-sa"` | no |
| <a name="input_workload_identity_federation"></a> [workload\_identity\_federation](#input\_workload\_identity\_federation) | Workload identity federation settings describing the building block runner. | <pre>object({<br/>    workload_identity_pool_identifier = string<br/>    subject_token_file_path           = string<br/>  })</pre> | n/a | yes |
| <a name="input_workload_identity_federation_trust"></a> [workload\_identity\_federation\_trust](#input\_workload\_identity\_federation\_trust) | What the pool provider trusts: the runner's OIDC issuer and audience, and the subject claims it accepts, each matched exactly. Take them from `version_latest.workload_identity_federation` of the building block definitions that run here. | <pre>object({<br/>    issuer   = string<br/>    audience = string<br/>    subjects = list(string)<br/>  })</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_binding_label"></a> [binding\_label](#output\_binding\_label) | Label the building block sets on each RoleBinding it creates, so the cleanup CronJob finds it. |
| <a name="output_cluster_role"></a> [cluster\_role](#output\_cluster\_role) | ClusterRole the building block binds developers to. |
| <a name="output_credentials_json"></a> [credentials\_json](#output\_credentials\_json) | External account credentials for the building block's service account. Points the runner at its own OIDC token file, which it exchanges for a short-lived access token. |
| <a name="output_expiry_annotation"></a> [expiry\_annotation](#output\_expiry\_annotation) | Annotation the building block sets to the RoleBinding's expiry, in UTC RFC 3339 (`YYYY-MM-DDTHH:MM:SSZ`). |
| <a name="output_namespaces"></a> [namespaces](#output\_namespaces) | Namespaces the building block can grant access to. |
| <a name="output_service_account_email"></a> [service\_account\_email](#output\_service\_account\_email) | Email of the service account the building block runs as. |
<!-- END_TF_DOCS -->

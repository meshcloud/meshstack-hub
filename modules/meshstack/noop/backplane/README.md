# NoOp Backplane — Self-Hosted Cloud Run Runner

This optional backplane provisions a self-hosted meshStack building block runner on Google Cloud Run.
It serves as an example and testing preparation when potentially running the NoOp Building Block on a different
runner than the built-in meshStack runner.

## What it provisions

| Resource                           | Purpose                                                                                             |
|------------------------------------|-----------------------------------------------------------------------------------------------------|
| `tls_private_key` (RSA 4096)       | Runner identity key pair — public key registered in meshStack, private key stored in Secret Manager |
| `meshstack_api_key`                | meshStack credentials the runner uses to poll and update building block runs                        |
| `google_secret_manager_secret` × 3 | Stores the RSA private key, runner config YAML, and meshStack client secret                         |
| `google_cloud_run_v2_service`      | Runs the meshStack runner container                                                                 |
| `meshstack_building_block_runner`  | Registers the runner in meshStack with `TERRAFORM` implementation type                              |

## Runner container mounts

The Cloud Run service mounts the following secrets into the container:

| Mount path                          | Content                                                                                                            |
|-------------------------------------|--------------------------------------------------------------------------------------------------------------------|
| `/config/runner-config.yml`         | Rendered from `runner-config.yml` with `RUNNER_UUID`, `RUNNER_API_URL`, and `RUNNER_API_KEY_CLIENT_ID` substituted |
| `/keys/runner-private.pem`          | RSA 4096 private key (PEM)                                                                                         |
| `$RUNNER_API_CLIENT_SECRET` env var | meshStack API client secret                                                                                        |

Adjust the mount paths in `main.tf` if your runner image expects a different layout.

## Prerequisites

- The `cloudrun.googleapis.com` and `secretmanager.googleapis.com` APIs must be enabled in `gcp_project_id`.
- The meshStack provider is configured via the `meshstack_endpoint` variable. Supply admin credentials via `MESHSTACK_CLIENT_ID` and `MESHSTACK_CLIENT_SECRET` environment variables (or `TF_VAR_*` equivalents).

## Outputs

| Output                  | Description                                                                                           |
|-------------------------|-------------------------------------------------------------------------------------------------------|
| `runner_ref`            | Wire into `meshstack_building_block_definition.version_spec.runner_ref` in `meshstack_integration.tf` |
| `cloud_run_service_url` | URL of the deployed Cloud Run service                                                                 |

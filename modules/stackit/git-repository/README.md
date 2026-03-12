# STACKIT Git Repository Module

This module wires the full meshStack integration for the STACKIT Git Repository building block.

It combines:

- `backplane/`: shared static configuration and pre-checks
- `buildingblock/`: tenant-facing repository provisioning logic
- `meshstack_integration.tf`: registration of the building block definition in meshStack

## What the meshStack integration provides

`meshstack_integration.tf` creates a `meshstack_building_block_definition` with:

- workspace-level target type
- static inputs from backplane (`forgejo_base_url`, `forgejo_token`, `forgejo_organization`)
- user inputs (`name`, `description`, `private`, `use_template`, `template_repo_path`, `webhook_url`)
- outputs exposed to users (`repository_html_url`, `repository_clone_url`, `repository_ssh_url`, `summary`)

This allows platform teams to publish a reusable self-service Git repository building block for tenants.

## Backplane behavior

The backplane ensures that `forgejo_organization` exists before building block usage:

- it calls the Forgejo org endpoint via `data "http"`, authenticated with the configured token
- if the org is missing (`status_code != 200`), it creates it via `resource "gitea_org"`

Because the lookup call is authenticated, this also validates that the configured token is working against the target Forgejo instance.

---
name: meshstack-hub
description: >
  Covers finding a ready-made building block module on meshStack Hub (hub.meshcloud.io), copying it
  into the user's own repository pinned to a Git commit, and what a human must set up in the cloud
  first (the backplane). Use when asked to offer a cloud service as a building block in meshStack,
  to find an OpenTofu module for a building block, to add, pin or upgrade a hub module, to set up
  the cloud identity a building block runs with, or when code references meshcloud/meshstack-hub.
---

# meshStack Hub

This skill is for agents and people who **use** modules from meshStack Hub. It lives in the hub
repository, so it changes together with the modules.

New to meshStack? Start at the [meshStack agent context](https://docs.meshcloud.io/agent-context/index.md).
It explains meshStack, its concepts and which login an agent should use, and it links back here for
hub modules.

Three rules apply to everything below:

- **Plan before apply.** Run `tofu plan`, show the user what it creates, changes and destroys, and
  apply only after they agree. See
  [Always plan before apply](https://raw.githubusercontent.com/meshcloud/terraform-provider-meshstack/main/skills/terraform-provider-meshstack/SKILL.md#always-plan-before-apply).
- **Ask before anything that destroys.** A plan that destroys or replaces a definition or a
  backplane breaks the building blocks that run on it.
- **Cloud credentials come from a human.** Never invent, guess or commit them. See
  [Set up the backplane](#set-up-the-backplane).

## What a hub module is

[meshStack Hub](https://hub.meshcloud.io) is a public catalog of OpenTofu modules that a platform
team can offer in meshStack as building blocks. The code lives in
[github.com/meshcloud/meshstack-hub](https://github.com/meshcloud/meshstack-hub). A building block
definition is what the platform team offers. A building block is one instance of it that an
application team orders.

A hub module is one folder, `modules/<platform>/<service>/`:

| Part | What it is | Who runs it |
|---|---|---|
| `buildingblock/` | The module that creates what an application team orders, for example one Key Vault | meshStack's building block runner, on every run of every building block |
| `backplane/` | What the building block needs before anyone can order it: a cloud identity for the runner, its permissions, sometimes shared resources. Optional. | The platform team, usually through `meshstack_integration.tf` |
| `meshstack_integration.tf` | Connects both to meshStack: it calls `backplane/` and creates the `meshstack_building_block_definition` that points at `buildingblock/` | The platform team, as a copy in their own repository |

`buildingblock/README.md` describes the module for platform engineers; its front matter holds
`name`, `supportedPlatforms` and `description`. `backplane/README.md` says what the backplane creates
and which permissions the person who applies it needs. The text application teams see in the
meshStack marketplace is the `readme` inside `meshstack_integration.tf`.

Two things in the hub are not building blocks. `modules/<platform>/meshstack_integration.tf`, one
level up, connects a cloud platform itself to meshStack (`meshstack_platform`, landing zones).
[Reference architectures](https://hub.meshcloud.io/reference-architectures), in
`reference-architectures/`, combine several hub modules into one solution, such as a landing zone.

## Find a module

People browse [hub.meshcloud.io](https://hub.meshcloud.io). A module page is
`https://hub.meshcloud.io/platforms/<platform>/definitions/<platform>-<service>`, for example
[Azure Key Vault](https://hub.meshcloud.io/platforms/azure/definitions/azure-key-vault) for
`modules/azure/key-vault`. The site renders in the browser, so a plain HTTP fetch returns a page
without the module. Read the repository instead, cloned outside the user's repository:

```sh
git clone --filter=blob:none https://github.com/meshcloud/meshstack-hub.git /tmp/meshstack-hub
cd /tmp/meshstack-hub
grep -H '^name:' modules/*/*/buildingblock/README.md       # every module and its name
grep -il '<keyword>' modules/*/*/buildingblock/README.md    # modules that mention a service
ls modules/*/*/meshstack_integration.tf                     # modules ready to use as code
```

Without git, read one file at a time from
`https://raw.githubusercontent.com/meshcloud/meshstack-hub/main/modules/<platform>/<service>/<file>`.

For each candidate, read these files in this order:

1. `buildingblock/README.md` — what the module creates, and on which platform.
2. `meshstack_integration.tf` — the `variable` blocks at the top are its interface, and a variable
   without `default` is required. The `readme` in `spec` is what application teams will see.
3. `backplane/README.md` — what must exist in the cloud first, and which rights the person who
   sets it up needs. See [Set up the backplane](#set-up-the-backplane).

When more than one module fits, show the user the candidates with their descriptions and let them
choose.

## Use a module from your own repository

The user keeps their meshStack configuration as code in their own repository; meshcloud calls it a
foundation repository. Copy the module's `meshstack_integration.tf` into it at a pinned commit and
edit the copy there, as the setup guide on hub.meshcloud.io does. The copy is then the user's code:
they review it like their own, and can change what its variables do not cover. When the user needs
no such change, they can call the module from the hub instead; see
[Call the module instead of copying it](#call-the-module-instead-of-copying-it).

1. Get the newest commit of the hub, and copy the file at that commit:

   ```sh
   git -C /tmp/meshstack-hub fetch origin main
   git -C /tmp/meshstack-hub rev-parse origin/main     # the full SHA to pin
   git -C /tmp/meshstack-hub show <sha>:modules/<platform>/<service>/meshstack_integration.tf > <dir>/meshstack_integration.tf
   ```

   Without a clone, download
   `https://raw.githubusercontent.com/meshcloud/meshstack-hub/<sha>/modules/<platform>/<service>/meshstack_integration.tf`.

2. Give the copy a directory of its own and use it as a root module, unless the user's repository
   already has a layout for this, such as one directory per building block:

   ```
   <dir>/
   ├── meshstack_integration.tf   the copy, pinned as in "Pin a version"
   ├── providers.tf               provider "meshstack", and one provider per cloud the module uses
   └── terraform.tfvars           values for the required variables, never a secret
   ```

   Add the state backend the user's repository uses. The copy brings its own
   `terraform { required_providers }` block, and OpenTofu allows only one per module. In a directory
   that already has one, `tofu init` fails with `Duplicate required providers configuration`, so
   merge the two blocks there.

3. Pin the copy, as [Pin a version](#pin-a-version) shows.
4. Set the required variables, for example for `modules/azure/key-vault`:

   ```hcl
   azure_tenant_id = "<entra-tenant-id>"
   azure_scope     = "/providers/Microsoft.Management/managementGroups/<landing-zones>"

   meshstack = {
     owning_workspace_identifier = "<workspace>"
   }
   ```

5. Run `tofu init` and `tofu plan`, and show the plan to the user.

`owning_workspace_identifier` is the identifier of the workspace that will own the definition, not
its display name. Set up the `meshstack` provider as
[Log in](https://raw.githubusercontent.com/meshcloud/terraform-provider-meshstack/main/skills/terraform-provider-meshstack/SKILL.md#log-in)
shows. After `tofu init`, `tofu providers` lists every provider the directory needs, including the
ones the backplane needs. Hub modules need OpenTofu 1.12 or newer (or Terraform 1.15 or newer),
because `hub` is a `const` variable that `init` reads to resolve the backplane's source.

After the apply, `tofu output building_block_definition` shows the definition's `uuid` and
`version_ref`, the definition version to order.

### Pin a version

The hub has no release tags. A version is a full commit SHA on `main`. The copy still points back
into the hub in three places, all through `var.hub.git_ref`:

- the `source` of `module "backplane"`, which `tofu init` downloads;
- the `ref_name` of the definition's implementation: the commit of `buildingblock/` that meshStack's
  runner checks out on every run;
- the logo URL in `symbol`.

`variable "hub"` sets `git_ref` to `main` twice: in the `optional(string, "main")` fallback and in
the `default`. Replace both with the full SHA the file was copied at, then check that every line
that points into the hub uses `var.hub.git_ref` or that SHA. A few files write `main` into the
`symbol` URL directly; replace that too.

```sh
grep -n 'git_ref\|meshstack-hub\|"main"' <dir>/meshstack_integration.tf
```

All of them must name the same full SHA. With `main`, every run takes whatever is on `main` at
that moment, and every `tofu init` takes the newest backplane, so a hub change reaches the user's
building blocks and cloud without a plan in their repository.

The **Use as Code** snippet on a module page on hub.meshcloud.io is this file with provider blocks
added. It also says `main`, so take the file from Git as shown above, where you know the commit.

`hub.bbd_draft` defaults to `true` and keeps the definition version a draft. A draft can only be
ordered in the workspace that owns the definition. Set it to `false` once a test order works; see
[Release a version](https://raw.githubusercontent.com/meshcloud/terraform-provider-meshstack/main/skills/terraform-provider-meshstack/SKILL.md#release-a-version)
for what a release means for existing building blocks.

### Upgrade to a newer commit

The old SHA is the one in the copy's `variable "hub"`.

1. Read what changed in the module. A subject with `!`, such as `feat(azure/key-vault)!: ...`, marks
   a breaking change:

   ```sh
   git -C /tmp/meshstack-hub fetch origin main
   git -C /tmp/meshstack-hub rev-parse origin/main     # the new SHA
   git -C /tmp/meshstack-hub log --format='%h %s' <old-sha>..<new-sha> -- modules/<platform>/<service>
   git -C /tmp/meshstack-hub diff <old-sha> <new-sha> -- modules/<platform>/<service>/meshstack_integration.tf
   ```

2. Apply that diff to the copy by hand, and keep the user's own edits. Then set the new SHA in
   `variable "hub"`. Changes in `backplane/` and `buildingblock/` come with the new SHA and need no
   edit in the copy.
3. If the definition is released (`bbd_draft = false`), set `bbd_draft = true` in the same edit.
   The new SHA changes the definition version, and a released version cannot change: the apply
   fails with `Updating a version_spec in non-draft (released) state is not allowed`. With `true`,
   the apply creates the next version as a draft. After a test order works, set `false` again to
   release it; see
   [Release a version](https://raw.githubusercontent.com/meshcloud/terraform-provider-meshstack/main/skills/terraform-provider-meshstack/SKILL.md#release-a-version).
4. Run `tofu init` and `tofu plan`, and show the plan to the user. Stop and ask when it destroys or
   replaces anything in the backplane: the building blocks of the definition run with that
   identity.

### Call the module instead of copying it

A root module can call the module folder from the hub, pinned to a commit, instead of copying its
`meshstack_integration.tf`. Nothing is copied, so the user cannot change what the variables do not
cover. The SHA goes into two places: the `?ref=` of `source`, and `hub.git_ref`. With only the
`?ref=`, the backplane, the definition's `ref_name` and the logo still point at `main`.

```hcl
module "key_vault" {
  source = "github.com/meshcloud/meshstack-hub//modules/azure/key-vault?ref=<sha>"

  hub = {
    git_ref   = "<sha>"
    bbd_draft = true
  }

  azure_tenant_id = "<entra-tenant-id>"
  azure_scope     = "/providers/Microsoft.Management/managementGroups/<landing-zones>"

  meshstack = {
    owning_workspace_identifier = "<workspace>"
  }
}

output "building_block_definition" {
  value = module.key_vault.building_block_definition
}
```

Give the root a `providers.tf` as in step 2 above, with a `required_providers` entry for
`meshcloud/meshstack` and each cloud provider. Without it, `provider "meshstack"` in the root
resolves to `hashicorp/meshstack`, and `tofu init` fails.

In a Terragrunt repository, a unit calls the same folder with
`terraform { source = "git::https://github.com/meshcloud/meshstack-hub.git//modules/<platform>/<service>?ref=<sha>" }`
and sets `hub = { git_ref = "<sha>", bbd_draft = true }` in its `inputs`. Keep the SHA in one place,
for example a `locals` block that both read, so that the two cannot point at different commits.

To upgrade, read what changed as in step 1 of [Upgrade to a newer commit](#upgrade-to-a-newer-commit),
then set the new SHA in both places, and follow steps 3 and 4 there.

### A module without `meshstack_integration.tf`

Some modules have only `buildingblock/`, and maybe `backplane/`. Create the definition yourself, as
[Create a building block definition](https://raw.githubusercontent.com/meshcloud/terraform-provider-meshstack/main/skills/terraform-provider-meshstack/SKILL.md#create-a-building-block-definition)
shows. Point its OpenTofu implementation at the repository
`https://github.com/meshcloud/meshstack-hub.git`, the path `modules/<platform>/<service>/buildingblock`
and a commit SHA as the ref. Take its inputs from `variables.tf` and the README in `buildingblock/`,
and call `backplane/` as a module with the same `?ref=`.

## Set up the backplane

A building block runs on meshStack's building block runner, not on the user's machine. To create
resources in a cloud, the runner needs an identity there with the right permissions, and the
backplane creates that identity. Many backplanes use workload identity federation: the cloud trusts
the runner's token, and no secret exists. Some create a long-lived key and pass it to the definition
as a sensitive input. That key is then in the OpenTofu state, so the state belongs in a protected
backend, never in Git.

Creating an identity and granting it permissions needs administrator rights in the cloud, for
example `User Access Administrator` on an Azure management group, or the right to create IAM roles
in AWS. So a human sets this up: the user, or the cloud team they ask. Never ask the user to paste a
secret into the chat.

Read `backplane/README.md` of the module (for example the
[Azure Key Vault backplane](https://raw.githubusercontent.com/meshcloud/meshstack-hub/main/modules/azure/key-vault/backplane/README.md)),
then ask the user in one message for:

- **The scope**: values for the required cloud variables, for example `azure_tenant_id` and
  `azure_scope` for an Azure module, or `stackit_project_id` for a STACKIT module.
- **A cloud login with the permissions the README lists**, in the shell where OpenTofu runs, for
  example through `az login`, `aws sso login` or `gcloud auth application-default login`. If the
  user does not give you these rights, they run `tofu apply` themselves after you have shown them
  the plan.
- **One-time steps the README names.** For example, an AWS module with `aws_oidc_provider_arn` needs
  [`modules/aws/oidc-provider`](https://raw.githubusercontent.com/meshcloud/meshstack-hub/main/modules/aws/oidc-provider/README.md)
  applied once per AWS account, and a GCP project may need an API turned on by its owner.
- **Credentials for a module without a cloud backplane.** For example, `github/repository` takes the
  ID, installation ID and private key of a GitHub App. Pass a secret as a `TF_VAR_<name>`
  environment variable or from the user's secret store, never in a committed file.
- **The runner.** If the user runs their own building block runner, its uuid goes into
  `building_block_runner_uuid`. Without it, the definition runs on the shared runner meshStack
  hosts.

In the plan for the first apply, point out what it creates in the cloud: identities, role
definitions and role assignments. They decide what the runner may do in the user's cloud, so the
user sees them before they exist.

A building block needs its backplane for every run, including the run that deletes it. Before you
delete the copy or apply a plan that destroys its backplane, check with the
[meshStack CLI skill](https://raw.githubusercontent.com/meshcloud/meshstack-cli/main/skills/meshstack-cli/SKILL.md)
whether building blocks of the definition still exist, and ask the user.

## Next steps

`tofu apply` of the copy creates the definition through the meshStack Terraform provider. Continue
with the
[`terraform-provider-meshstack` skill](https://raw.githubusercontent.com/meshcloud/terraform-provider-meshstack/main/skills/terraform-provider-meshstack/SKILL.md):

- [Log in](https://raw.githubusercontent.com/meshcloud/terraform-provider-meshstack/main/skills/terraform-provider-meshstack/SKILL.md#log-in)
  for the provider login.
- [Create a building block definition](https://raw.githubusercontent.com/meshcloud/terraform-provider-meshstack/main/skills/terraform-provider-meshstack/SKILL.md#create-a-building-block-definition)
  for what the definition holds and how to check it in meshStack.
- [Release a version](https://raw.githubusercontent.com/meshcloud/terraform-provider-meshstack/main/skills/terraform-provider-meshstack/SKILL.md#release-a-version)
  once a test order works.

To order a test building block and read its run, use
[Ordering a building block](https://raw.githubusercontent.com/meshcloud/meshstack-cli/main/skills/meshstack-cli/SKILL.md#ordering-a-building-block)
and [Why a run failed](https://raw.githubusercontent.com/meshcloud/meshstack-cli/main/skills/meshstack-cli/SKILL.md#why-a-run-failed)
in the CLI skill. For everything else about meshStack, go back to the
[meshStack agent context](https://docs.meshcloud.io/agent-context/index.md).

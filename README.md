# meshStack Hub

The meshStack Hub provides a collection of ready-to-use Terraform modules that can directly be
used in your meshStack as Building Blocks.

See what's out there on [hub.meshcloud.io](https://hub.meshcloud.io)!

![readme IMG](https://github.com/meshcloud/meshstack-hub/raw/main/.github/readme_img.png)

## 📦 Available Modules

We recommend looking at all available modules on [hub.meshcloud.io](https://hub.meshcloud.io).
Alternatively, you can find all available modules in the `modules/` directory separated by platform.

Example modules:

AWS S3 Module – Provision S3 buckets with encryption and logging.

## 🏗️ Reference Architectures

Reference architectures show how to combine multiple building blocks into a complete
platform capability. See the [`reference-architectures/`](reference-architectures/) directory
for curated, end-to-end blueprints.

## 🏢️ Structure

All Terraform modules are listed in the `modules/` directory.
This directory is split into subdirectories for each platform.
In a platform's directory, you will find all modules that are available for that platform.
Additionally, you might also find a `meshstack_integration.tf` and `README.md` file in a platform
directory. These allow you to integrate a given platform directly with meshStack.

A single module is structured as follows:

```
module_name/
    buildingblock/ -- This is the *actual* Terraform module that provisions resources for application teams.
        main.tf
        provider.tf
        outputs.tf
        variables.tf
        README.md -- This explains the module and how to use it from a platform engineering perspective.
        APP_TEAM_README.md -- This explains the module and how to use it from an application team perspective.
        logo.png -- This is the logo that is shown in the meshStack Hub and in the meshStack UI (if imported).
    backplane/ -- This is the Terraform code that provisions all supporting resources such as roles & techical users.
        <... Terraform files ...>
        README.md -- This explains the backplane module and how to use it. (optional)
```

## 🔧 Usage

Any module that you find works within meshStack.
The easiest option is to directly import the module from the [meshStack Hub](https://hub.meshcloud.io) into your own meshStack by clicking the "Import" button on the module page.

Refer to each module's README.md for specific usage instructions such as needed input variables.

## Change the Runner of a Definition

A module with workload identity federation makes your cloud trust the tokens of one building block
runner. meshStack runs a building block with the definition version it was created with, and a
released version keeps its runner. So after a runner change, the building blocks on older versions
still present the tokens of the old runner. The module must trust both runners until you have
upgraded them.

1. Update the module to a Hub commit in which its `meshstack` variable has
   `additional_trusted_runner_refs`. A module without this field does not support the steps below.
2. Add the old runner to `meshstack.additional_trusted_runner_refs`, in the apply that changes the
   runner or earlier:

   ```hcl
   meshstack = {
     owning_workspace_identifier    = "my-platform-team"
     runner_ref                     = { kind = "meshBuildingBlockRunner", uuid = "<uuid of the new runner>" }
     additional_trusted_runner_refs = [{ kind = "meshBuildingBlockRunner", uuid = "<uuid of the old runner>" }]
   }
   ```

   For a GCP module, also set `original_runner_ref` to the old runner, and never remove it. The
   released versions contain the name of the identity provider of their runner, and the backplane
   changes these names when you remove `original_runner_ref`.
3. Apply. Your cloud now trusts both runners, and the new version of the definition uses the new
   runner.
4. Release the new version. Then upgrade the building blocks in the Admin Area under
   **Marketplace** > **Building Blocks**.
5. Remove the old runner from `additional_trusted_runner_refs` when no building block is on a
   version that uses it.

Without `meshstack.runner_ref`, a definition uses the default runner of your meshStack. When that
default changes, the next apply moves the definition to the new default. Add the old runner to
`additional_trusted_runner_refs` before that apply. The plan shows its uuid in the change of
`version_spec.runner_ref`.

Some STACKIT modules log in as a service account that already exists, and their backplane creates
no trust for a runner. The STACKIT Service Account Federation building block creates this trust.
After you change the runner of such a module, run that building block again, so that STACKIT trusts
the new runner.

## For AI agents

An AI agent that works with meshStack for you starts with the
[meshStack agent context](https://docs.meshcloud.io/agent-context/index.md). It explains which
login to use, the guardrails and every task. To let the agent find a module and set it up in your
meshStack, point it at the [`meshstack-hub` skill](skills/meshstack-hub/SKILL.md) too, for example
from your repository's agent instructions.

## Community, Discussion & Support

The meshStack Hub is a 🌤️ [cloudfoundation.org community](https://cloudfoundation.org/?ref=github-collie-cli) project.
Reach out to us on the [cloudfoundation.org slack](http://cloudfoundationorg.slack.com).

## 🛠️ How to Contribute

Thank you for your interest in contributing Terraform modules or building blocks to **meshstack-hub**! To ensure high quality and consistency, please follow the steps below:

---

### 1. Fork & Clone

```bash
git clone git@github.com:<your-username>/meshstack-hub.git
cd meshstack-hub
git checkout -b feature/your-module
```

---

### 2. Enter Nix Development Shell

The repository provides a `flake.nix` that includes pre-commit hooks, formatting and validation:

```bash
nix develop
```

This prepares the environment with `opentofu`, `terraform-docs`, `pre-commit`, and any other needed tools automatically.

> **Recommended:** Use [OpenTofu](https://opentofu.org/) (`tofu`) as your IaC runtime. Modules in this repo require OpenTofu ≥ 1.12 (or Terraform ≥ 1.15) for `const` variable support. The Nix development shell provides OpenTofu by default.

---

### 3. Write and Organize Your Terraform Module

- Add your module under the correct provider folder (e.g. `aws/`, `azure/`, `gcp/`).
- Include:
  - `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`, `providers.tf`, `APP_TEAM_README.md`
  - A `README.md` describing the module’s purpose and usage.

---

### 4. Run Pre‑commit Hooks

Hooks are already available in your shell:

```bash
pre-commit run --all-files
```

They include checks like `terraform fmt`, shellcheck and `ci/validate_modules.sh`.

`task lint` runs shellcheck, ruff, ty, actionlint and zizmor on every shell and Python script and every
workflow in the repo, module scripts included. CI runs it on every PR; run it inside `nix develop`
before you push.

The `<!-- BEGIN_TF_DOCS -->` sections of module READMEs are generated by CI. After your PR is merged,
CI regenerates them and pushes the result to `main`. Leave these sections as they are and do not run
terraform-docs. A comment on your PR shows what CI will change. To preview it locally, run `task docs`.

Commiting will auto-run them:

```bash
git add .
git commit -m "feat: add new vpc module"
```

---

This is typically triggered via pre-commit hooks during commits.

---

### 7. Add or Update Tests

- Run them inside `nix develop`, for example:

Ensure all tests pass and code/formats stay clean.

---

### 8. Push & Open a Pull Request

```bash
git push origin feature/your-module
```

In your PR description include:
- Module purpose, inputs/outputs
- Provider details
- Any breaking changes or migration notes
- Confirmation that all tests and checks passed

---

### 9. Review & Merge

CI will rerun all hooks/tests. A maintainer will review and merge or request adjustments.

---

## ✅ Summary Checklist

1. [ ] Module in the correct provider folder
2. [ ] `main.tf`, `variables.tf`, `outputs.tf`, `README.md`
3. [ ] `nix develop` used to enter environment ✅
4. [ ] `pre-commit run --all-files` passed ✅
5. [ ] `tofu init`, `validate`, `fmt` passed ✅
6. [ ] Tests added/updated and passing ✅
7. [ ] PR includes description & proof that all checks passed ✅

---

Thanks again for helping to improve **meshstack-hub**! 🚀

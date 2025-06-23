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

## 🏢️ Structure

All Terraform modules are listed in the `modules/` directory.
This directory is split into subdirectories for each platform.
In a platform's directory, you will find all modules that are available for that platform.

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

The repository provides a `flake.nix` that includes pre-commit hooks, formatting, validation, and docs generation:

```bash
nix develop
```

This prepares the environment with `terraform`, `terraform-docs`, `pre-commit`, and any other needed tools automatically.

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

They include checks like `terraform fmt`, `terraform validate` and automated docs via `terraform-docs`.

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
5. [ ] `terraform init`, `validate`, `fmt` passed ✅
6. [ ] `terraform-docs markdown .` docs generated ✅
7. [ ] Tests added/updated and passing ✅
8. [ ] PR includes description & proof that all checks passed ✅

---

Thanks again for helping to improve **meshstack-hub**! 🚀

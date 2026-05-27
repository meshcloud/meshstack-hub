---
description: BBD readme conventions for meshstack-hub modules. Covers the required inline HCL pattern (chomp heredoc), required sections (description, usage motivation, usage examples, shared responsibility table), markdown rules, a copy-paste template, and anti-patterns to avoid.
---

# BBD Readme Conventions

The `readme` field of `meshstack_building_block_definition.spec` is the **user-facing documentation** shown to application teams in the meshStack marketplace. It must be written for developers — not platform engineers — and must explain what the building block does, when to reach for it, and exactly what each party is responsible for.

## Rationale

- **One-file copy/paste**: Platform engineers import building blocks by copying `meshstack_integration.tf` into their IaC runtime. Keeping the readme inline means they get the full building block — resources, variables, and documentation — in a single file with no missing dependencies.
- **No stale file references**: A `file("buildingblock/APP_TEAM_README.md")` path breaks the moment the integration file is used outside the hub repo, which is exactly the copy/paste scenario above.
- **Consistency**: All building blocks in the hub use the same pattern, so agents and platform engineers know where to look.

<!-- scorecard-checks: bbd_readme -->
## Standard Pattern

Always write the `readme` field as a `chomp(<<-EOT)` heredoc directly in `meshstack_integration.tf`.

```hcl
readme = chomp(<<-EOT
  Description of the building block in plain text. No heading here — start directly
  with what this building block is and does, in one or two sentences.

  ## 🎯 When to use it

  Use this building block when you:
  - <condition 1>
  - <condition 2>

  ## 💡 Usage examples

  **Example 1: <scenario title>**
  <1–2 sentence scenario description from the application team's perspective>

  **Example 2: <scenario title>** *(optional)*
  <1–2 sentence scenario description>

  ## 📊 Shared Responsibility

  | Responsibility | Platform Team | Application Team |
  |---|:---:|:---:|
  | <provision/manage resource> | ✅ | ❌ |
  | <another platform concern> | ✅ | ❌ |
  | <application concern> | ❌ | ✅ |
  | <another app concern> | ❌ | ✅ |
  EOT
)
```

**Why `chomp(<<-EOT)`?**
- `<<-` (dash heredoc) strips leading whitespace so the body can be indented with the surrounding HCL block.
- `chomp()` removes the trailing newline that heredocs always append, keeping the field value clean.
- Do **not** use `<<EOT` (without dash) — it will include the HCL indentation as literal content.

## Required Sections

<!-- scorecard-checks: bbd_readme_no_leading_heading -->
### Description

The **first content** in the readme must be plain prose — no `#` heading. Start directly with
what the building block is and does. One or two sentences is enough.

```
This building block provisions an Azure Storage Account for application teams, including
blob containers and SAS token generation, so teams can store and access files without
managing the underlying infrastructure.
```

Not like this:
```
## Azure Storage Account

This building block provisions...
```

<!-- scorecard-checks: bbd_readme_shared_responsibility -->
### Shared Responsibility Table

Every readme **must** end with a shared responsibility table. It must:
- Use a markdown table with `| Responsibility | Platform Team | Application Team |` as the header.
- Use `✅` for "managed/provided" and `❌` for "not in scope".
- Align the emoji columns using `:---:` for centering.
- Cover the key concerns for the building block — what the platform team provisions and manages vs. what the application team owns.

```markdown
| Responsibility | Platform Team | Application Team |
|---|:---:|:---:|
| Provision and configure the storage account | ✅ | ❌ |
| Manage SAS token lifecycle | ✅ | ❌ |
| Blob container naming and structure | ❌ | ✅ |
| Application data lifecycle and cleanup | ❌ | ✅ |
```

### Usage Motivation

Explain **who** this building block is for and **when** they should reach for it. Write from
the perspective of an application team member choosing between options. A short bulleted list
works well here.

### Usage Examples

Provide **1–2 concrete scenarios** written from the developer's perspective. Keep them short
(1–3 sentences each). Focus on what the developer wants to accomplish, not on Terraform.

## Markdown Rules

- **No leading heading** — the description paragraph comes before any `##` heading.
- Use `##` headings (not `#`) for top-level sections inside the readme field.
- Emoji are encouraged in headings (🎯, 💡, 📊) and in the shared responsibility table (✅, ❌).
- Avoid unnecessary formatting — plain prose reads better than excessive bold/italic.
- Do not add a trailing `---` separator at the very end of the readme value.

## Template

Copy this template into `meshstack_integration.tf` and fill in the `<…>` placeholders:

```hcl
readme = chomp(<<-EOT
  <One or two sentences describing what this building block does and what it creates.>

  ## 🎯 When to use it

  Use this building block when you:
  - <scenario or precondition 1>
  - <scenario or precondition 2>

  ## 💡 Usage examples

  **Example 1: <title>**
  <1–2 sentences from a developer's perspective>

  **Example 2: <title>**
  <1–2 sentences from a developer's perspective>

  ## 📊 Shared Responsibility

  | Responsibility | Platform Team | Application Team |
  |---|:---:|:---:|
  | <platform concern 1> | ✅ | ❌ |
  | <platform concern 2> | ✅ | ❌ |
  | <application concern 1> | ❌ | ✅ |
  | <application concern 2> | ❌ | ✅ |
  EOT
)
```

## Anti-patterns

- ❌ `readme = file("buildingblock/APP_TEAM_README.md")` — breaks copy/paste, path resolves only inside the hub repo.
- ❌ `readme = file("buildingblock/README.md")` — that file is for terraform-docs and catalog metadata (YAML front-matter), not the BBD readme.
- ❌ `readme = <<EOT` (without dash) — includes HCL indentation as literal whitespace in the output.
- ❌ Starting the readme with a `#` heading — the first content must be plain-text description.
- ❌ Omitting the shared responsibility table — application teams need a clear handoff line.
- ❌ Writing the readme from the platform engineer's perspective — the audience is the application team.

## Checklist for BBD Readmes

- [ ] `readme` field is a `chomp(<<-EOT)` heredoc inline in `meshstack_integration.tf`
- [ ] First content is plain-text description — no `#` heading
- [ ] Includes a "When to use it" section with at least one bullet
- [ ] Includes 1–2 usage examples written from the developer's perspective
- [ ] Includes a shared responsibility table with `✅` and `❌` emojis
- [ ] Table uses `|---|:---:|:---:|` alignment row
- [ ] No `file()` call for the readme value
- [ ] No trailing `---` at the end of the readme value

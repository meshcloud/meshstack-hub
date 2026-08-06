---
name: Link
supportedPlatforms:
  - meshstack
description: Publishes a URL as an orderable building block — a resource URL plus a markdown summary, provisioning no infrastructure.
# No cloud-side setup to perform: the module takes three static inputs and provisions nothing.
requiresBackplane: false
---

# Link Building Block

This building block provisions **no infrastructure**. It exists so platform teams can publish a
URL — a training platform, an internal portal, a support desk, an onboarding guide — as a
first-class entry in the meshStack marketplace that application teams can order, find again in
meshPanel, and read a proper description of.

Every user-visible aspect is set by the platform team when the building block definition is
created (see `meshstack_integration.tf`): display name, description, catalog readme, logo, target
type, and the markdown summary shown after deployment. One module therefore backs many distinct
marketplace entries — instantiate it once per link you want to offer.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [terraform_data.link](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_summary"></a> [summary](#input\_summary) | Markdown rendered for the application team after deployment. Empty falls back to a generated one-liner pointing at the URL. | `string` | n/a | yes |
| <a name="input_title"></a> [title](#input\_title) | Human-readable name of the linked resource. Used in the generated summary. | `string` | n/a | yes |
| <a name="input_url"></a> [url](#input\_url) | Target of the link. Surfaced as the building block's resource URL. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_summary"></a> [summary](#output\_summary) | Markdown rendered for the application team after deployment. |
| <a name="output_url"></a> [url](#output\_url) | The linked resource, rendered as a deep link in meshPanel. |
<!-- END_TF_DOCS -->

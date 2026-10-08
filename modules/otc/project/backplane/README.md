# T Cloud Public Project – Backplane

This module sets up what the T Cloud Public Project building block, and the federation mapping
building block, need inside a T Cloud Public domain:

- **An IAM user with an access key**, in a group holding the domain roles in `domain_roles`
  (default `secu_admin`, Security Administrator) and the roles in `project_roles` on all projects
  (default `te_admin`, Tenant Administrator). The building blocks authenticate as it.
- **Optionally, the company identity provider** (SAML or OIDC), federated into the domain so
  meshStack project users sign in as virtual users. It is seeded with one base rule that lets any
  federated user sign in without permissions, and changes to its rules are ignored afterwards: the
  federation mapping building block owns them.
- **With the identity provider, the mapping bucket.** Every project building block records its group
  membership there as `mappings/<project>.json`. A bucket policy lets the building block user write
  under `mappings/`.

## Why a static credential

The `opentelekomcloud` provider cannot exchange an OIDC token for credentials, so meshStack's
workload identity is not usable and the building blocks need a static access key. The user is
programmatic-only, and the key reaches meshStack as sensitive static inputs.

## Prerequisites

- A T Cloud Public domain, and credentials for it holding Security Administrator to apply this
  module.
- For federation: the identity provider's SAML metadata, or its OIDC issuer, client ID and JWKS
  signing keys. The claim or attribute named in `email_attribute` must carry exactly the email
  address meshStack knows for each user.

## Usage

```hcl
module "project_backplane" {
  source = "./backplane"

  identity_provider = {
    name     = "entra"
    protocol = "oidc"
    oidc = {
      provider_url = "https://login.microsoftonline.com/<tenant-id>/v2.0"
      client_id    = "<app-client-id>"
      signing_key  = file("jwks.json")
    }
  }
}
```

## Operational notes

- Do not edit the identity provider's mapping by hand. The federation mapping building block
  rebuilds it from the bucket and overwrites any hand-written rule.
- Rotating the access key: taint `opentelekomcloud_identity_credential_v3.building_block` and
  re-apply the integration. The new key reaches meshStack through the definitions' sensitive inputs
  on the same apply.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_opentelekomcloud"></a> [opentelekomcloud](#requirement\_opentelekomcloud) | >= 1.37.0, < 2.0.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.6.0, < 4.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [opentelekomcloud_identity_credential_v3.building_block](https://registry.terraform.io/providers/opentelekomcloud/opentelekomcloud/latest/docs/resources/identity_credential_v3) | resource |
| [opentelekomcloud_identity_group_v3.building_block](https://registry.terraform.io/providers/opentelekomcloud/opentelekomcloud/latest/docs/resources/identity_group_v3) | resource |
| [opentelekomcloud_identity_provider.this](https://registry.terraform.io/providers/opentelekomcloud/opentelekomcloud/latest/docs/resources/identity_provider) | resource |
| [opentelekomcloud_identity_role_assignment_v3.domain](https://registry.terraform.io/providers/opentelekomcloud/opentelekomcloud/latest/docs/resources/identity_role_assignment_v3) | resource |
| [opentelekomcloud_identity_role_assignment_v3.project](https://registry.terraform.io/providers/opentelekomcloud/opentelekomcloud/latest/docs/resources/identity_role_assignment_v3) | resource |
| [opentelekomcloud_identity_user_group_membership_v3.building_block](https://registry.terraform.io/providers/opentelekomcloud/opentelekomcloud/latest/docs/resources/identity_user_group_membership_v3) | resource |
| [opentelekomcloud_identity_user_v3.building_block](https://registry.terraform.io/providers/opentelekomcloud/opentelekomcloud/latest/docs/resources/identity_user_v3) | resource |
| [opentelekomcloud_obs_bucket.mappings](https://registry.terraform.io/providers/opentelekomcloud/opentelekomcloud/latest/docs/resources/obs_bucket) | resource |
| [opentelekomcloud_obs_bucket_policy.mappings](https://registry.terraform.io/providers/opentelekomcloud/opentelekomcloud/latest/docs/resources/obs_bucket_policy) | resource |
| [random_string.bucket_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [opentelekomcloud_identity_role_v3.domain](https://registry.terraform.io/providers/opentelekomcloud/opentelekomcloud/latest/docs/data-sources/identity_role_v3) | data source |
| [opentelekomcloud_identity_role_v3.project](https://registry.terraform.io/providers/opentelekomcloud/opentelekomcloud/latest/docs/data-sources/identity_role_v3) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_domain_roles"></a> [domain\_roles](#input\_domain\_roles) | Domain-scoped IAM system roles granted to the building block user, by role `name` (not display<br/>name). `secu_admin` (Security Administrator) covers creating projects, groups, role assignments,<br/>agencies and federation mappings. | `list(string)` | <pre>[<br/>  "secu_admin"<br/>]</pre> | no |
| <a name="input_identity_provider"></a> [identity\_provider](#input\_identity\_provider) | The customer's identity provider, federated into the domain so meshStack project users log in as<br/>virtual users, and the bucket project building blocks record their membership in. Null skips<br/>both: the building block still creates projects and groups, but nobody is mapped into them. | <pre>object({<br/>    name     = string<br/>    protocol = string<br/><br/>    # SAML: the IdP's metadata XML.<br/>    metadata = optional(string)<br/><br/>    # OIDC: the IdP's issuer, client and signing keys (JWKS JSON).<br/>    oidc = optional(object({<br/>      provider_url           = string<br/>      client_id              = string<br/>      signing_key            = string<br/>      authorization_endpoint = optional(string)<br/>      scopes                 = optional(list(string), ["openid"])<br/>    }))<br/><br/>    # The SAML attribute or OIDC claim that carries the user's email. Project building blocks<br/>    # match meshStack users against it, so it must hold exactly the address meshStack knows.<br/>    email_attribute = optional(string, "email")<br/>  })</pre> | `null` | no |
| <a name="input_project_roles"></a> [project\_roles](#input\_project\_roles) | IAM system roles granted to the building block user on all projects, by role `name`.<br/>`te_admin` (Tenant Administrator) lets the federation mapping building block create its function<br/>in the management project. It adds little to `secu_admin`, which may grant any role anyway. | `list(string)` | <pre>[<br/>  "te_admin"<br/>]</pre> | no |
| <a name="input_user_name"></a> [user\_name](#input\_user\_name) | Name of the IAM user the building block authenticates as. Override when deploying several backplanes into one domain. | `string` | `"mesh-project"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_access_key"></a> [access\_key](#output\_access\_key) | Access key of the IAM user the building blocks authenticate as. |
| <a name="output_identity_provider_email_attribute"></a> [identity\_provider\_email\_attribute](#output\_identity\_provider\_email\_attribute) | SAML attribute or OIDC claim that carries the user's email address. |
| <a name="output_identity_provider_login_link"></a> [identity\_provider\_login\_link](#output\_identity\_provider\_login\_link) | Console login link for federated users, or null without federation. |
| <a name="output_identity_provider_name"></a> [identity\_provider\_name](#output\_identity\_provider\_name) | Name of the federated identity provider, or null without federation. |
| <a name="output_mapping_bucket"></a> [mapping\_bucket](#output\_mapping\_bucket) | OBS bucket project building blocks record their group membership in, or null without federation. |
| <a name="output_secret_key"></a> [secret\_key](#output\_secret\_key) | Secret key of the IAM user the building blocks authenticate as. |
| <a name="output_user_name"></a> [user\_name](#output\_user\_name) | Name of the IAM user the building blocks authenticate as. |
<!-- END_TF_DOCS -->

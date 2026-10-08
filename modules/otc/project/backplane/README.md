# T Cloud Public Project – Backplane

This module sets up what the T Cloud Public Project building block needs inside a T Cloud Public
domain:

- **An IAM user and group** the building block authenticates as, holding the domain roles in
  `domain_roles` — by default `secu_admin` (Security Administrator), which covers creating
  projects, groups, role assignments and federation mappings.
- **Optionally, the customer's identity provider** (SAML or OIDC), federated into the domain so
  meshStack project users sign in as virtual users. It starts with one base mapping rule that lets
  any federated user sign in without permissions; every project building block adds the rules that
  put its users into its project groups.

## Why a password and not workload identity federation

The `opentelekomcloud` provider cannot exchange an OIDC token for credentials, so meshStack's
workload identity is not usable yet and the building block needs a static credential. The user is
programmatic-only, and the password is handed to meshStack as a sensitive static input. It is a
password rather than an AK/SK because the building block's federation script calls the IAM API
directly, and a password gets it a token without implementing AK/SK request signing.

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

- The identity provider's mapping is shared by every project building block, and this module
  ignores later changes to it. Do not edit the mapping by hand: the next project run rewrites the
  rules it owns, and a hand-written rule that names a project group is treated as owned by it.
- Rotating the password: taint `random_password.building_block` and re-apply the integration; the
  new password reaches meshStack through the definition's sensitive input on the same apply.

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
| [opentelekomcloud_identity_group_v3.building_block](https://registry.terraform.io/providers/opentelekomcloud/opentelekomcloud/latest/docs/resources/identity_group_v3) | resource |
| [opentelekomcloud_identity_provider.this](https://registry.terraform.io/providers/opentelekomcloud/opentelekomcloud/latest/docs/resources/identity_provider) | resource |
| [opentelekomcloud_identity_role_assignment_v3.domain](https://registry.terraform.io/providers/opentelekomcloud/opentelekomcloud/latest/docs/resources/identity_role_assignment_v3) | resource |
| [opentelekomcloud_identity_user_group_membership_v3.building_block](https://registry.terraform.io/providers/opentelekomcloud/opentelekomcloud/latest/docs/resources/identity_user_group_membership_v3) | resource |
| [opentelekomcloud_identity_user_v3.building_block](https://registry.terraform.io/providers/opentelekomcloud/opentelekomcloud/latest/docs/resources/identity_user_v3) | resource |
| [random_password.building_block](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [opentelekomcloud_identity_role_v3.domain](https://registry.terraform.io/providers/opentelekomcloud/opentelekomcloud/latest/docs/data-sources/identity_role_v3) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_domain_roles"></a> [domain\_roles](#input\_domain\_roles) | Domain-scoped IAM system roles granted to the building block user, by role `name` (not display<br/>name). `secu_admin` (Security Administrator) covers creating projects, groups, role assignments<br/>and federation mappings — the only things the building block touches. | `list(string)` | <pre>[<br/>  "secu_admin"<br/>]</pre> | no |
| <a name="input_identity_provider"></a> [identity\_provider](#input\_identity\_provider) | The customer's identity provider, federated into the domain so meshStack project users log in as<br/>virtual users. Null skips federation: the building block still creates projects and groups, but<br/>nobody is mapped into them. | <pre>object({<br/>    name     = string<br/>    protocol = string<br/><br/>    # SAML: the IdP's metadata XML.<br/>    metadata = optional(string)<br/><br/>    # OIDC: the IdP's issuer, client and signing keys (JWKS JSON).<br/>    oidc = optional(object({<br/>      provider_url           = string<br/>      client_id              = string<br/>      signing_key            = string<br/>      authorization_endpoint = optional(string)<br/>      scopes                 = optional(list(string), ["openid"])<br/>    }))<br/><br/>    # The SAML attribute or OIDC claim that carries the user's email. Project building blocks<br/>    # match meshStack users against it, so it must hold exactly the address meshStack knows.<br/>    email_attribute = optional(string, "email")<br/>  })</pre> | `null` | no |
| <a name="input_user_name"></a> [user\_name](#input\_user\_name) | Name of the IAM user the building block authenticates as. Override when deploying several backplanes into one domain. | `string` | `"mesh-project"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_identity_provider_email_attribute"></a> [identity\_provider\_email\_attribute](#output\_identity\_provider\_email\_attribute) | SAML attribute or OIDC claim project building blocks match meshStack users' email against. |
| <a name="output_identity_provider_login_link"></a> [identity\_provider\_login\_link](#output\_identity\_provider\_login\_link) | Console login link for federated users, or null without federation. |
| <a name="output_identity_provider_name"></a> [identity\_provider\_name](#output\_identity\_provider\_name) | Name of the federated identity provider whose mapping project building blocks extend, or null without federation. |
| <a name="output_password"></a> [password](#output\_password) | Password of the IAM user the building block authenticates as. |
| <a name="output_user_name"></a> [user\_name](#output\_user\_name) | Name of the IAM user the building block authenticates as. |
<!-- END_TF_DOCS -->

---
name: STACKIT DNS Zone
supportedPlatforms:
  - stackit
description: Creates a STACKIT DNS zone with a wildcard record, so applications on the platform get real hostnames.
---

# STACKIT DNS Zone — Building Block

Creates a DNS zone in the tenant's STACKIT project and, when given a target address, a wildcard `A`
record inside it.

## Why the default parent is `stackit.run`

STACKIT delegates `stackit.run` to its own customers, so a zone created under it resolves without
anyone owning a domain or changing nameservers. A platform that owns a domain passes
`parent_domain` and gets real names instead.

## Why a wildcard record

A platform hands out one hostname per application and stage. Provisioning a record for each of them
would put DNS in the path of every application order. One `*.<zone>` record pointing at the ingress
load balancer removes that step: any hostname under the zone resolves, and the ingress controller
decides what answers.

Leaving `wildcard_target_ip` null creates the zone and nothing else, for a platform that manages its
records elsewhere.

## Certificates

The zone is enough for HTTP-01 certificate issuance, which is what the STACKIT Kubernetes Platform
reference architecture uses: the hostname resolves to the load balancer, so the ACME server reaches
the challenge. A wildcard certificate needs DNS-01 instead, which needs a credential for this zone
inside the cluster — this building block does not create one.

## Permissions

The run authenticates via Workload Identity Federation as the platform's STACKIT service account,
which needs the `dns.zone.*` permissions. Both `editor` and the narrower `dns.admin` carry all of
them.

## Taking over a zone

With `imports = {zone_id, record_set_id}`, the building block takes over an existing zone named
`<subdomain>.<parent_domain>` and its wildcard record set. With
`release_on_destroy` set, destroying the building block leaves both in place.
`release_on_destroy` cannot change once they are managed.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_stackit"></a> [stackit](#requirement\_stackit) | >= 0.98.0, < 1.0.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_wildcard"></a> [wildcard](#module\_wildcard) | ./modules/record-set | n/a |
| <a name="module_zone"></a> [zone](#module\_zone) | ./modules/zone | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_contact_email"></a> [contact\_email](#input\_contact\_email) | Address in the zone's SOA record, where a resolver problem is reported. | `string` | n/a | yes |
| <a name="input_default_ttl"></a> [default\_ttl](#input\_default\_ttl) | Default TTL in seconds for records in this zone. | `number` | n/a | yes |
| <a name="input_imports"></a> [imports](#input\_imports) | Existing zone `<subdomain>.<parent_domain>` and its wildcard record set to take over; null creates both. | <pre>object({<br/>    zone_id       = string<br/>    record_set_id = string<br/>  })</pre> | `null` | no |
| <a name="input_parent_domain"></a> [parent\_domain](#input\_parent\_domain) | Domain this zone is created under. | `string` | n/a | yes |
| <a name="input_release_on_destroy"></a> [release\_on\_destroy](#input\_release\_on\_destroy) | Leave the zone and its record set in place on destroy. Cannot change once they are managed. | `bool` | `false` | no |
| <a name="input_stackit_project_id"></a> [stackit\_project\_id](#input\_stackit\_project\_id) | STACKIT project the zone is created in. | `string` | n/a | yes |
| <a name="input_stackit_region"></a> [stackit\_region](#input\_stackit\_region) | STACKIT region the zone is placed in. | `string` | n/a | yes |
| <a name="input_subdomain"></a> [subdomain](#input\_subdomain) | Label this zone occupies under `parent_domain`, e.g. `my-platform` for `my-platform.stackit.run`. | `string` | n/a | yes |
| <a name="input_wildcard_target_ip"></a> [wildcard\_target\_ip](#input\_wildcard\_target\_ip) | IPv4 address the `*.<zone>` A record points at. Null creates no record. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_summary"></a> [summary](#output\_summary) | Markdown summary shown on the building block. |
| <a name="output_zone_id"></a> [zone\_id](#output\_zone\_id) | Id of the created zone, for records made by another building block. |
| <a name="output_zone_name"></a> [zone\_name](#output\_zone\_name) | Fully qualified name of the zone. Hostnames are built under it. |
| <a name="output_zone_url"></a> [zone\_url](#output\_zone\_url) | The zone in the STACKIT portal. |
<!-- END_TF_DOCS -->

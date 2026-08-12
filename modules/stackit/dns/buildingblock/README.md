---
name: STACKIT DNS Zone
supportedPlatforms:
  - stackit
description: Creates a STACKIT DNS zone with its record sets and a service account key that lets cert-manager and ExternalDNS manage records at runtime.
---

# STACKIT DNS Zone Building Block

This building block module creates one DNS zone in a STACKIT project, the record sets inside it, and
a service account key that lets a workload manage those records at runtime. The cert-manager DNS-01
solver and ExternalDNS both take that key.

The module is used in two ways. A reference architecture sources it directly as a Terraform module,
which keeps STACKIT resources out of the architecture itself. A team orders it as a building block
through meshStack, wired up by the `meshstack_integration.tf` at the module root.

## One zone, one project, one credential

STACKIT DNS is project-scoped end to end. `stackit_dns_record_set` carries its own `project_id` and
that project must own the `zone_id`, and the SKE `extensions.dns` block has no field for a foreign
project or a foreign credential. The zone, its records and the credential that writes them
therefore all belong to one project.

## A free STACKIT subdomain admits exactly one label

This is measured against the live API, not assumed. Creating a two-label zone under `stackit.run`
is rejected before any delegation or project logic is reached:

```console
$ stackit dns zone create --project-id <p> --name aipoc-c6a37f-sub \
    --dns-name sub.aipoc-c6a37f.stackit.run
Error: create DNS zone: 400 Bad Request, status code 400, Body:
{"message":"zone dns name sub.aipoc-c6a37f.stackit.run has one error",
 "error":"subdomain 'sub.aipoc-c6a37f' should only have one level"}
```

The error is byte-for-byte identical with a correct NS delegation already in place in the parent
zone, and identical again in a freshly created second project. The project makes no difference.
`var.zone_name` carries a validation that rejects this shape at plan time rather than at apply.

The same name under a customer-owned domain fails differently — *"collides with a parent zone in a
different project and has no delegation"* — so STACKIT's cross-project delegation does exist and is
project-aware. It simply never gets reached for `stackit.run`, because the name check fires first.

So `likvid.stackit.run` is a zone, and everything below it is a record set in that zone. A cluster
reachable at `cluster1.likvid.stackit.run` with a wildcard below it needs two entries:

```hcl
records = {
  "cluster1"   = { type = "A", records = ["203.0.113.17"] }
  "*.cluster1" = { type = "A", records = ["203.0.113.17"] }
}
```

## The permission trade-off you are accepting

With a free STACKIT subdomain, every cluster and every application under `likvid.stackit.run` lives
in one zone, in one project, written with one credential. The key this module returns therefore
**can write any record in that zone, including over a record that belongs to another cluster.**
`dns.admin` is a project role — it cannot be narrowed to one zone, let alone to one name.

That is a real trade-off, not a detail:

- Hand the key only to workloads you would trust with the whole domain.
- Give each cluster its own name prefix and treat the prefixes as a convention, not as a boundary.
- If you need a real boundary, use a domain you own and give each tenant a delegated zone of its
  own in its own project. See the next section.

## Delegation — for customer-owned domains only

`var.delegation` writes the `NS` record that delegates this zone from a parent zone in another
STACKIT project. It is unset by default. Under a free STACKIT suffix the zone itself cannot exist,
so the module refuses that combination outright.

```hcl
zone_name = "cluster1.example.com"

delegation = {
  parent_zone_project_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" # the platform team's project
  parent_zone_name       = "example.com"
}
```

Two traps the code guards against, both seen in the proof-of-concept:

- **Trailing dots are load-bearing.** STACKIT relativises a record value that does not end in a dot
  against the zone, so `ns1.stackit.cloud` is stored as `ns1.stackit.cloud.<zone>.`. The default
  nameservers are `ns1.stackit.cloud.` and `ns2.stackit.zone.`, and a precondition rejects values
  without the dot. The same applies to `CNAME`, `MX` and `NS` values in `records`.
- **An orphaned NS record fails silently.** If the delegation is published and the zone behind it
  never appears, a direct query returns NOERROR with an empty answer and a referral, and a
  recursive resolver returns SERVFAIL — with no error at apply time. The module therefore creates
  the zone before the record, and a precondition refuses to delegate a name it is not creating.

## The DNS credential

`stackit_service_account_key.dns.json` is the raw service account key JSON that the
[STACKIT cert-manager webhook](https://github.com/stackitcloud/stackit-cert-manager-webhook) expects
as `sa.json`. Pass it, together with `zone_project_id`, to `modules/kubernetes/ingress`:

```hcl
dns01 = {
  zone_name = module.dns.zone_name
  stackit = {
    project_id          = module.dns.zone_project_id
    service_account_key = module.dns.dns_service_account_key
  }
}
```

Set `dns_service_account_enabled = false` when records are managed through Terraform only, or when
the backplane identity may not create service accounts. Both `dns_service_account_*` outputs are
`null` in that case.

`dns_service_account_key_ttl_days` is unset by default, so the key stays valid until it is deleted.
A key that expires has to be rotated by re-applying the building block before a certificate can
renew.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_stackit"></a> [stackit](#requirement\_stackit) | >= 0.110.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [stackit_authorization_project_role_assignment.dns](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/authorization_project_role_assignment) | resource |
| [stackit_dns_record_set.delegation](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/dns_record_set) | resource |
| [stackit_dns_record_set.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/dns_record_set) | resource |
| [stackit_dns_zone.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/dns_zone) | resource |
| [stackit_service_account.dns](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/service_account) | resource |
| [stackit_service_account_key.dns](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/service_account_key) | resource |
| [stackit_dns_zone.parent](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/data-sources/dns_zone) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_contact_email"></a> [contact\_email](#input\_contact\_email) | Contact address stored on the zone. Leave empty to let STACKIT pick its own default. | `string` | `""` | no |
| <a name="input_delegation"></a> [delegation](#input\_delegation) | Write the `NS` record that delegates this zone from a parent zone in another STACKIT project.<br/>Leave unset, which is the default and the usual case.<br/><br/>**This works only for a domain the customer owns.** Under a free STACKIT suffix such as<br/>`stackit.run` the zone itself cannot be created, so the delegation has nothing to point at — see<br/>the API error quoted in main.tf. The module refuses that combination.<br/><br/>`nameservers` must carry trailing dots. STACKIT relativises a value without one against the zone,<br/>so `ns1.stackit.cloud` is stored as `ns1.stackit.cloud.<zone>.` and the delegation points nowhere. | <pre>object({<br/>    parent_zone_project_id = string<br/>    parent_zone_name       = string<br/>    nameservers            = optional(list(string), ["ns1.stackit.cloud.", "ns2.stackit.zone."])<br/>    ttl                    = optional(number, 3600)<br/>  })</pre> | `null` | no |
| <a name="input_dns_service_account_enabled"></a> [dns\_service\_account\_enabled](#input\_dns\_service\_account\_enabled) | Create a service account with `dns.admin` on the zone's project and a key for it. cert-manager's DNS-01 solver and ExternalDNS both authenticate with that key. Turn it off when the consumer manages records through Terraform only, or when the backplane identity may not create service accounts. | `bool` | `true` | no |
| <a name="input_dns_service_account_key_ttl_days"></a> [dns\_service\_account\_key\_ttl\_days](#input\_dns\_service\_account\_key\_ttl\_days) | Validity of the DNS service account key in days. Leave unset to create a key that stays valid until it is deleted. A key that expires has to be rotated by re-applying the building block before a certificate can renew. | `number` | `null` | no |
| <a name="input_dns_service_account_name"></a> [dns\_service\_account\_name](#input\_dns\_service\_account\_name) | Name of the DNS service account. Defaults to `mesh-dns-<zone name with dots replaced by hyphens>`, which keeps two zones in the same project apart. | `string` | `null` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | STACKIT project ID the zone, its records and the DNS service account are created in. | `string` | n/a | yes |
| <a name="input_records"></a> [records](#input\_records) | Record sets to create in the zone, keyed by the name relative to the zone. A key of `cluster1` in<br/>the zone `likvid.stackit.run` gives `cluster1.likvid.stackit.run`, and `*.cluster1` gives the<br/>wildcard below it.<br/><br/>A value that is itself a domain name — the target of a `CNAME`, `MX` or `NS` record — must end in<br/>a dot. STACKIT relativises a value without one against the zone, so `example.com` is stored as<br/>`example.com.likvid.stackit.run.`.<pre>hcl<br/>records = {<br/>  "cluster1"   = { type = "A", records = ["203.0.113.17"] }<br/>  "*.cluster1" = { type = "A", records = ["203.0.113.17"] }<br/>}</pre> | <pre>map(object({<br/>    type    = string<br/>    records = list(string)<br/>    ttl     = optional(number)<br/>    comment = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_service_account_email"></a> [service\_account\_email](#input\_service\_account\_email) | Email of the STACKIT service account the provider authenticates as via workload identity federation. Leave unset when the caller supplies its own provider configuration. | `string` | `null` | no |
| <a name="input_stackit_region"></a> [stackit\_region](#input\_stackit\_region) | STACKIT region used as the provider's default. STACKIT DNS itself is global. Ignored when the caller supplies its own provider configuration. | `string` | `"eu01"` | no |
| <a name="input_zone_default_ttl"></a> [zone\_default\_ttl](#input\_zone\_default\_ttl) | Default time to live of records in the zone, in seconds. ExternalDNS and cert-manager both write records here, so a short value keeps changes visible quickly. | `number` | `300` | no |
| <a name="input_zone_description"></a> [zone\_description](#input\_zone\_description) | Description stored on the zone. Leave empty to store none. | `string` | `""` | no |
| <a name="input_zone_name"></a> [zone\_name](#input\_zone\_name) | DNS name of the zone, for example `likvid.stackit.run` or `platform.example.com`. No trailing dot.<br/><br/>A free STACKIT subdomain admits exactly one label. `likvid.stackit.run` is accepted and<br/>`cluster1.likvid.stackit.run` is rejected by the API, so everything below the zone has to be a<br/>record set in `records` rather than a zone of its own. See main.tf for the API error. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_delegation_record_fqdn"></a> [delegation\_record\_fqdn](#output\_delegation\_record\_fqdn) | Fully qualified name of the NS record created in the parent zone. Null when `delegation` is unset, which is the usual case. |
| <a name="output_dns_service_account_email"></a> [dns\_service\_account\_email](#output\_dns\_service\_account\_email) | Email of the service account that manages records in the zone. Null when `dns_service_account_enabled` is false. |
| <a name="output_dns_service_account_key"></a> [dns\_service\_account\_key](#output\_dns\_service\_account\_key) | STACKIT service account key as raw JSON, for the cert-manager DNS-01 solver and for ExternalDNS. It holds `dns.admin` on the zone's project, so it can write every record in every zone of that project. Null when `dns_service_account_enabled` is false. |
| <a name="output_record_fqdns"></a> [record\_fqdns](#output\_record\_fqdns) | Fully qualified name of every record set the module created, keyed the same way as the `records` input. |
| <a name="output_summary"></a> [summary](#output\_summary) | Summary with the zone, its records and the DNS credential. |
| <a name="output_zone_id"></a> [zone\_id](#output\_zone\_id) | UUID of the zone. |
| <a name="output_zone_name"></a> [zone\_name](#output\_zone\_name) | DNS name of the zone, for example `likvid.stackit.run`. Use it as the ExternalDNS zone filter and as the zone the cert-manager DNS-01 solver operates on. |
| <a name="output_zone_project_id"></a> [zone\_project\_id](#output\_zone\_project\_id) | STACKIT project ID the zone lives in. The DNS-01 solver has to name the same project, because STACKIT DNS is project-scoped. |
<!-- END_TF_DOCS -->

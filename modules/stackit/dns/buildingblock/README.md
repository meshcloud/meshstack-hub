---
name: STACKIT DNS Zone
supportedPlatforms:
  - stackit
description: Creates a STACKIT DNS zone with its record sets and a service account key that lets cert-manager and ExternalDNS manage records at runtime.
---

# STACKIT DNS Zone Building Block

This building block module creates one DNS zone in a STACKIT project, the record sets inside it, and
a service account key that lets a workload manage those records at runtime. The cert-manager DNS-01
solver and ExternalDNS both take that key. With `create_zone = false` the module skips the zone and
writes its record sets into a zone that already exists.

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

## One zone, many clusters

A zone is not a subzone, and that is what makes the shared zone work. STACKIT allows a record set
with a deeper name inside an existing zone, so a single platform-owned zone carries every cluster.
The platform team creates the zone once:

```hcl
module "zone" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/dns/buildingblock?ref=main"

  project_id = var.platform_project_id
  zone_name  = "likvid.stackit.run"
}
```

Each cluster then runs the module again with `create_zone = false` and writes only its own records
into that zone:

```hcl
module "cluster_dns" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/dns/buildingblock?ref=main"

  project_id                  = var.platform_project_id # the project that owns the zone
  zone_name                   = "likvid.stackit.run"
  create_zone                 = false
  dns_service_account_enabled = false

  wildcard = {
    label   = "cluster1"
    address = module.ingress.haproxy_lb_ip
  }
}
```

That gives the record set `*.cluster1.likvid.stackit.run`, and `wildcard_domain` returns
`cluster1.likvid.stackit.run` for the certificate. `zone_id` is optional here — the module looks the
zone up by its name with the `stackit_dns_zone` data source, which needs read access on the zone's
project.

## Apex or label, and why it matters

`wildcard.label` decides where the wildcard sits:

| `label` | Record set | Hostnames | Certificate |
|---|---|---|---|
| unset | `*.likvid.stackit.run` | `app.likvid.stackit.run` | `*.likvid.stackit.run` |
| `cluster1` | `*.cluster1.likvid.stackit.run` | `app.cluster1.likvid.stackit.run` | `*.cluster1.likvid.stackit.run` |

**Only one cluster can hold the wildcard at the zone apex.** The apex record is a single record set
in the zone, so the second cluster that writes it collides with the first one. The apex shape is
therefore the shape of a zone with exactly one cluster in it, which is what the SKE foundations have
today. Every cluster beyond the first needs a label, and the label is also what keeps a cluster's
certificate down to its own names instead of the whole domain.

Moving a cluster that already runs at the apex to a label renames every hostname it serves, from
`app.likvid.stackit.run` to `app.cluster1.likvid.stackit.run`. That is a breaking change for the
applications on it, so plan it as one.

The module cannot detect the collision for you. A second cluster runs from its own state, and
STACKIT offers no data source that lists the record sets of a zone, so the first sign of the clash
is the error the API returns at apply time.

## Moving an existing SKE foundation onto this module

The three SKE foundations create their zone and one apex wildcard by hand:

```hcl
resource "stackit_dns_zone" "this" {
  name     = "likvid-ske-starterkit"
  dns_name = "likvid.stackit.run"
}

resource "stackit_dns_record_set" "A" {
  name    = "*.likvid.stackit.run"
  type    = "A"
  records = [var.haproxy_lb_ip]
  comment = "Wildcard app routing to HAProxy ingress load balancer"
}
```

The module reproduces that record with `wildcard = { address = var.haproxy_lb_ip }` and no label:
the same fully qualified name, the same type, no TTL, and the same comment, which is the default of
`wildcard.comment`. Keep the zone's name with `zone_display_name = "likvid-ske-starterkit"`, because
STACKIT stores that name separately from the DNS name. Two `moved` blocks then carry the existing
state into the module and the plan stays empty:

```hcl
moved {
  from = stackit_dns_zone.this
  to   = module.dns.stackit_dns_zone.this[0]
}

moved {
  from = stackit_dns_record_set.A
  to   = module.dns.stackit_dns_record_set.wildcard[0]
}
```

## The permission trade-off you are accepting

With a free STACKIT subdomain, every cluster and every application under `likvid.stackit.run` lives
in one zone, in one project, written with one credential. The key this module returns therefore
**can write any record in that zone, including over a record that belongs to another cluster.**
`dns.admin` is a project role — it cannot be narrowed to one zone, let alone to one name.

A per-cluster label does not change that. `*.cluster1.likvid.stackit.run` is where the code writes,
not where the credential ends. **The label is a boundary this module draws, and the permission
system does not enforce it.** A cluster that gets the key can write outside its label, and nothing
in STACKIT stops it.

That is a real trade-off, not a detail:

- Hand the key only to workloads you would trust with the whole domain.
- Give each cluster its own label and treat the labels as a convention the code keeps, not as a
  boundary an attacker respects.
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
  zone_name          = module.dns.zone_name
  certificate_domain = module.dns.wildcard_domain
  stackit = {
    project_id          = module.dns.zone_project_id
    service_account_key = module.dns.dns_service_account_key
  }
}
```

The two names differ once the zone is shared. `zone_name` is the zone the DNS-01 solver is
authorised for, `likvid.stackit.run`, and `certificate_domain` is the domain the wildcard
certificate covers, `cluster1.likvid.stackit.run`. Leave `certificate_domain` unset and the
certificate covers the whole zone, which is what a single cluster at the apex wants.

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
| [stackit_dns_record_set.wildcard](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/dns_record_set) | resource |
| [stackit_dns_zone.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/dns_zone) | resource |
| [stackit_service_account.dns](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/service_account) | resource |
| [stackit_service_account_key.dns](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/service_account_key) | resource |
| [stackit_dns_zone.existing](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/data-sources/dns_zone) | data source |
| [stackit_dns_zone.parent](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/data-sources/dns_zone) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_contact_email"></a> [contact\_email](#input\_contact\_email) | Contact address stored on the zone. Leave empty to let STACKIT pick its own default. Only used when `create_zone` is `true`. | `string` | `""` | no |
| <a name="input_create_zone"></a> [create\_zone](#input\_create\_zone) | Create the zone. Leave this at `true` when the caller owns the zone.<br/><br/>Set it to `false` to write record sets into a zone that already exists and that another Terraform<br/>configuration owns. The platform team creates `likvid.stackit.run` once, and every cluster then<br/>adds its own record sets to that zone. STACKIT allows a record set with a deeper name inside an<br/>existing zone, so `*.cluster1.likvid.stackit.run` is a record set in `likvid.stackit.run` and not<br/>a zone of its own. See README.md. | `bool` | `true` | no |
| <a name="input_delegation"></a> [delegation](#input\_delegation) | Write the `NS` record that delegates this zone from a parent zone in another STACKIT project.<br/>Leave unset, which is the default and the usual case.<br/><br/>**This works only for a domain the customer owns.** Under a free STACKIT suffix such as<br/>`stackit.run` the zone itself cannot be created, so the delegation has nothing to point at — see<br/>the API error quoted in main.tf. The module refuses that combination.<br/><br/>`nameservers` must carry trailing dots. STACKIT relativises a value without one against the zone,<br/>so `ns1.stackit.cloud` is stored as `ns1.stackit.cloud.<zone>.` and the delegation points nowhere. | <pre>object({<br/>    parent_zone_project_id = string<br/>    parent_zone_name       = string<br/>    nameservers            = optional(list(string), ["ns1.stackit.cloud.", "ns2.stackit.zone."])<br/>    ttl                    = optional(number, 3600)<br/>  })</pre> | `null` | no |
| <a name="input_dns_service_account_enabled"></a> [dns\_service\_account\_enabled](#input\_dns\_service\_account\_enabled) | Create a service account with `dns.admin` on the zone's project and a key for it. cert-manager's DNS-01 solver and ExternalDNS both authenticate with that key. Turn it off when the consumer manages records through Terraform only, or when the backplane identity may not create service accounts. | `bool` | `true` | no |
| <a name="input_dns_service_account_key_ttl_days"></a> [dns\_service\_account\_key\_ttl\_days](#input\_dns\_service\_account\_key\_ttl\_days) | Validity of the DNS service account key in days. Leave unset to create a key that stays valid until it is deleted. A key that expires has to be rotated by re-applying the building block before a certificate can renew. | `number` | `null` | no |
| <a name="input_dns_service_account_name"></a> [dns\_service\_account\_name](#input\_dns\_service\_account\_name) | Name of the DNS service account. Defaults to `mesh-dns-<zone name with dots replaced by hyphens>`, which keeps two zones in the same project apart. | `string` | `null` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | STACKIT project ID that owns the zone. The record sets and the DNS service account are created in the same project, because STACKIT DNS is project-scoped. | `string` | n/a | yes |
| <a name="input_records"></a> [records](#input\_records) | Record sets to create in the zone, keyed by the name relative to the zone. A key of `cluster1` in<br/>the zone `likvid.stackit.run` gives `cluster1.likvid.stackit.run`, and `*.cluster1` gives the<br/>wildcard below it.<br/><br/>A value that is itself a domain name — the target of a `CNAME`, `MX` or `NS` record — must end in<br/>a dot. STACKIT relativises a value without one against the zone, so `example.com` is stored as<br/>`example.com.likvid.stackit.run.`.<pre>hcl<br/>records = {<br/>  "cluster1"   = { type = "A", records = ["203.0.113.17"] }<br/>  "*.cluster1" = { type = "A", records = ["203.0.113.17"] }<br/>}</pre> | <pre>map(object({<br/>    type    = string<br/>    records = list(string)<br/>    ttl     = optional(number)<br/>    comment = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_service_account_email"></a> [service\_account\_email](#input\_service\_account\_email) | Email of the STACKIT service account the provider authenticates as via workload identity federation. Leave unset when the caller supplies its own provider configuration. | `string` | `null` | no |
| <a name="input_stackit_region"></a> [stackit\_region](#input\_stackit\_region) | STACKIT region used as the provider's default. STACKIT DNS itself is global. Ignored when the caller supplies its own provider configuration. | `string` | `"eu01"` | no |
| <a name="input_wildcard"></a> [wildcard](#input\_wildcard) | One wildcard `A` record that sends every hostname below a domain to the same address, usually the<br/>ingress controller's load balancer. Leave it unset to create no wildcard.<br/><br/>`label` decides where the wildcard sits. Leave it unset and the record is `*.<zone_name>`, which<br/>covers every hostname directly under the zone. Set it to the cluster's name and the record is<br/>`*.<label>.<zone_name>`, which covers the hostnames of that one cluster.<br/><br/>**Only one cluster can hold the wildcard at the zone apex.** The second cluster that writes<br/>`*.<zone_name>` collides with the first one, so every cluster beyond the first needs a `label` of<br/>its own. See README.md.<pre>hcl<br/>wildcard = {<br/>  label   = "cluster1"<br/>  address = "203.0.113.17"<br/>}</pre> | <pre>object({<br/>    address = string<br/>    label   = optional(string)<br/>    ttl     = optional(number)<br/>    comment = optional(string, "Wildcard app routing to HAProxy ingress load balancer")<br/>  })</pre> | `null` | no |
| <a name="input_zone_default_ttl"></a> [zone\_default\_ttl](#input\_zone\_default\_ttl) | Default time to live of records in the zone, in seconds. ExternalDNS and cert-manager both write records here, so a short value keeps changes visible quickly. Only used when `create_zone` is `true`. | `number` | `300` | no |
| <a name="input_zone_description"></a> [zone\_description](#input\_zone\_description) | Description stored on the zone. Leave empty to store none. Only used when `create_zone` is `true`. | `string` | `""` | no |
| <a name="input_zone_display_name"></a> [zone\_display\_name](#input\_zone\_display\_name) | Name STACKIT shows for the zone, which is separate from its DNS name. Defaults to `zone_name`. Only used when `create_zone` is `true`. Set it when an existing zone carries a different name and you move it into this module, so the plan stays empty. | `string` | `null` | no |
| <a name="input_zone_id"></a> [zone\_id](#input\_zone\_id) | UUID of the zone to write the record sets into. Only used when `create_zone` is `false`. Leave it<br/>unset to let the module look the zone up by `zone_name` in `project_id`, which needs read access<br/>on that project. | `string` | `null` | no |
| <a name="input_zone_name"></a> [zone\_name](#input\_zone\_name) | DNS name of the zone, for example `likvid.stackit.run` or `platform.example.com`. No trailing dot.<br/>With `create_zone = false` this is the name of the existing zone the record sets go into.<br/><br/>A free STACKIT subdomain admits exactly one label. `likvid.stackit.run` is accepted and<br/>`cluster1.likvid.stackit.run` is rejected by the API, so everything below the zone has to be a<br/>record set in `records` or in `wildcard` rather than a zone of its own. See main.tf for the API<br/>error.<br/><br/>Leave it `null` to switch the module off, which creates and reads nothing. A composition needs<br/>that because this module configures its own STACKIT provider for the meshStack run, and Terraform<br/>refuses `count` on a module that does so. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_delegation_record_fqdn"></a> [delegation\_record\_fqdn](#output\_delegation\_record\_fqdn) | Fully qualified name of the NS record created in the parent zone. Null when `delegation` is unset, which is the usual case. |
| <a name="output_dns_service_account_email"></a> [dns\_service\_account\_email](#output\_dns\_service\_account\_email) | Email of the service account that manages records in the zone. Null when `dns_service_account_enabled` is false. |
| <a name="output_dns_service_account_key"></a> [dns\_service\_account\_key](#output\_dns\_service\_account\_key) | STACKIT service account key as raw JSON, for the cert-manager DNS-01 solver and for ExternalDNS. It holds `dns.admin` on the zone's project, so it can write every record in every zone of that project. Null when `dns_service_account_enabled` is false. |
| <a name="output_record_fqdns"></a> [record\_fqdns](#output\_record\_fqdns) | Fully qualified name of every record set the module created, keyed the same way as the `records` input. |
| <a name="output_summary"></a> [summary](#output\_summary) | Summary with the zone, its records and the DNS credential. Null when the module is switched off with `zone_name = null`. |
| <a name="output_wildcard_domain"></a> [wildcard\_domain](#output\_wildcard\_domain) | Domain the wildcard record covers — the zone itself when no label is set, and `<label>.<zone_name>` otherwise. Application hostnames live under it, and a wildcard certificate has to be issued for `*.<wildcard_domain>`. Null when `wildcard` is unset. |
| <a name="output_wildcard_record_fqdn"></a> [wildcard\_record\_fqdn](#output\_wildcard\_record\_fqdn) | Fully qualified name of the wildcard record set. Null when `wildcard` is unset. |
| <a name="output_zone_id"></a> [zone\_id](#output\_zone\_id) | UUID of the zone the record sets were written into, whether this module created it or not. |
| <a name="output_zone_name"></a> [zone\_name](#output\_zone\_name) | DNS name of the zone, for example `likvid.stackit.run`. Use it as the ExternalDNS zone filter and as the zone the cert-manager DNS-01 solver operates on. |
| <a name="output_zone_project_id"></a> [zone\_project\_id](#output\_zone\_project\_id) | STACKIT project ID the zone lives in. The DNS-01 solver has to name the same project, because STACKIT DNS is project-scoped. |
<!-- END_TF_DOCS -->

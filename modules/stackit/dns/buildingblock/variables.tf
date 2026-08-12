# ── Backplane inputs (static, set once per building block definition) ──────────

variable "project_id" {
  type        = string
  nullable    = false
  description = "STACKIT project ID the zone, its records and the DNS service account are created in."
}

variable "service_account_email" {
  type        = string
  nullable    = true
  default     = null
  description = "Email of the STACKIT service account the provider authenticates as via workload identity federation. Leave unset when the caller supplies its own provider configuration."
}

variable "stackit_region" {
  type        = string
  nullable    = false
  default     = "eu01"
  description = "STACKIT region used as the provider's default. STACKIT DNS itself is global. Ignored when the caller supplies its own provider configuration."
}

# ── Zone ───────────────────────────────────────────────────────────────────────

variable "zone_name" {
  type        = string
  nullable    = false
  description = <<-EOT
  DNS name of the zone, for example `likvid.stackit.run` or `platform.example.com`. No trailing dot.

  A free STACKIT subdomain admits exactly one label. `likvid.stackit.run` is accepted and
  `cluster1.likvid.stackit.run` is rejected by the API, so everything below the zone has to be a
  record set in `records` rather than a zone of its own. See main.tf for the API error.
  EOT

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$", var.zone_name))
    error_message = "zone_name must be a lowercase domain name with at least two labels and no trailing dot, for example likvid.stackit.run."
  }

  validation {
    condition     = !endswith(var.zone_name, ".stackit.run") || length(split(".", var.zone_name)) == 3
    error_message = "A zone under stackit.run may carry exactly one label, for example likvid.stackit.run. STACKIT rejects a deeper name with \"subdomain '<name>' should only have one level\". Put the deeper names into `records` instead, or use a domain you own."
  }
}

variable "zone_default_ttl" {
  type        = number
  nullable    = false
  default     = 300
  description = "Default time to live of records in the zone, in seconds. ExternalDNS and cert-manager both write records here, so a short value keeps changes visible quickly."
}

variable "contact_email" {
  type        = string
  nullable    = false
  default     = ""
  description = "Contact address stored on the zone. Leave empty to let STACKIT pick its own default."
}

variable "zone_description" {
  type        = string
  nullable    = false
  default     = ""
  description = "Description stored on the zone. Leave empty to store none."
}

# ── Records ────────────────────────────────────────────────────────────────────

variable "records" {
  type = map(object({
    type    = string
    records = list(string)
    ttl     = optional(number)
    comment = optional(string)
  }))
  nullable = false
  default  = {}

  description = <<-EOT
  Record sets to create in the zone, keyed by the name relative to the zone. A key of `cluster1` in
  the zone `likvid.stackit.run` gives `cluster1.likvid.stackit.run`, and `*.cluster1` gives the
  wildcard below it.

  A value that is itself a domain name — the target of a `CNAME`, `MX` or `NS` record — must end in
  a dot. STACKIT relativises a value without one against the zone, so `example.com` is stored as
  `example.com.likvid.stackit.run.`.

  ```hcl
  records = {
    "cluster1"   = { type = "A", records = ["203.0.113.17"] }
    "*.cluster1" = { type = "A", records = ["203.0.113.17"] }
  }
  ```
  EOT

  validation {
    condition     = alltrue([for r in var.records : length(r.records) > 0])
    error_message = "Every record set must carry at least one value in `records`."
  }

  validation {
    condition     = alltrue([for r in var.records : contains(["A", "AAAA", "ALIAS", "CAA", "CNAME", "DNAME", "MX", "NS", "PTR", "SRV", "TXT"], r.type)])
    error_message = "Each record set `type` must be one of A, AAAA, ALIAS, CAA, CNAME, DNAME, MX, NS, PTR, SRV, TXT."
  }
}

# ── Delegation — customer-owned domains only ───────────────────────────────────

variable "delegation" {
  type = object({
    parent_zone_project_id = string
    parent_zone_name       = string
    nameservers            = optional(list(string), ["ns1.stackit.cloud.", "ns2.stackit.zone."])
    ttl                    = optional(number, 3600)
  })
  nullable = true
  default  = null

  description = <<-EOT
  Write the `NS` record that delegates this zone from a parent zone in another STACKIT project.
  Leave unset, which is the default and the usual case.

  **This works only for a domain the customer owns.** Under a free STACKIT suffix such as
  `stackit.run` the zone itself cannot be created, so the delegation has nothing to point at — see
  the API error quoted in main.tf. The module refuses that combination.

  `nameservers` must carry trailing dots. STACKIT relativises a value without one against the zone,
  so `ns1.stackit.cloud` is stored as `ns1.stackit.cloud.<zone>.` and the delegation points nowhere.
  EOT

  validation {
    condition     = var.delegation == null ? true : !endswith(var.delegation.parent_zone_name, "stackit.run")
    error_message = "Delegation under stackit.run is not possible. STACKIT allows exactly one label below a free subdomain and rejects the subzone with \"subdomain '<name>' should only have one level\", so the NS record would delegate a name that cannot exist. Use a domain you own, or drop `delegation` and put the names into `records`."
  }

  validation {
    condition     = var.delegation == null ? true : length(var.delegation.nameservers) > 0
    error_message = "delegation.nameservers must contain at least one nameserver, otherwise the delegated zone is not reachable. STACKIT requires both ns1.stackit.cloud. and ns2.stackit.zone. for its SLA to hold."
  }
}

# ── DNS credential ─────────────────────────────────────────────────────────────

variable "dns_service_account_enabled" {
  type        = bool
  nullable    = false
  default     = true
  description = "Create a service account with `dns.admin` on the zone's project and a key for it. cert-manager's DNS-01 solver and ExternalDNS both authenticate with that key. Turn it off when the consumer manages records through Terraform only, or when the backplane identity may not create service accounts."
}

variable "dns_service_account_name" {
  type        = string
  nullable    = true
  default     = null
  description = "Name of the DNS service account. Defaults to `mesh-dns-<zone name with dots replaced by hyphens>`, which keeps two zones in the same project apart."
}

variable "dns_service_account_key_ttl_days" {
  type        = number
  nullable    = true
  default     = null
  description = "Validity of the DNS service account key in days. Leave unset to create a key that stays valid until it is deleted. A key that expires has to be rotated by re-applying the building block before a certificate can renew."
}

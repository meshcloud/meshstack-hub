# Runs against this root, which is the wrapper, so every assertion below travels through `./zone`
# and back out again. That is deliberate: the resources moved into the submodule and these runs are
# what shows the outputs still carry the same values afterwards.

variables {
  project_id            = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
  service_account_email = "mesh-dns@sa.stackit.cloud"
}

mock_provider "stackit" {
  mock_resource "stackit_dns_zone" {
    defaults = {
      zone_id = "11111111-2222-3333-4444-555555555555"
    }
  }

  mock_resource "stackit_service_account" {
    defaults = {
      email = "mesh-dns@sa.stackit.cloud"
    }
  }

  mock_resource "stackit_service_account_key" {
    defaults = {
      json = "{\"mock\":\"service-account-key\"}"
    }
  }
}

# The platform team's run: it creates the zone every cluster later shares, and the credential that
# writes into it. This is the shape `reference-architectures/stackit-landingzone` drives, except
# that it calls `./zone` directly so it can put `count` on it.
run "platform_team_creates_the_shared_zone" {
  command = plan

  variables {
    zone_name = "likvid.stackit.run"
  }

  assert {
    condition     = output.zone_name == "likvid.stackit.run"
    error_message = "zone_name must be read off the created zone, so callers wiring it somewhere depend on the zone existing"
  }

  assert {
    condition     = output.zone_id == "11111111-2222-3333-4444-555555555555"
    error_message = "zone_id must come from the created zone"
  }

  assert {
    condition     = output.zone_project_id == "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    error_message = "zone_project_id must pass through"
  }

  assert {
    condition     = output.dns_service_account_email == "mesh-dns@sa.stackit.cloud"
    error_message = "the DNS service account must be created and its email returned"
  }

  # This run planning at all is also the assertion on the derived service account name. STACKIT caps
  # it at 20 characters and the provider enforces that in its schema, so the earlier
  # `mesh-dns-<zone with dots replaced>` failed here with 27 characters for this very zone name.
  assert {
    condition     = nonsensitive(output.dns_service_account_key) == "{\"mock\":\"service-account-key\"}"
    error_message = "the DNS key is the credential cert-manager authenticates with and must reach the caller"
  }
}

# A cluster's run: no zone of its own, no credential of its own, just its label inside the shared
# zone. `reference-architectures/stackit-kubernetes` drives this shape.
#
# The zone is named by `zone_id` here rather than looked up by name. The lookup path cannot be
# covered by a test: `zone_id` is a required attribute of `data.stackit_dns_zone` rather than a
# computed one, so `mock_data` refuses to supply it ("Non-computed field `zone_id` is not allowed to
# be overridden") and the record sets that depend on it then have no zone to write into.
run "cluster_writes_its_label_into_the_shared_zone" {
  command = plan

  variables {
    zone_name                   = "likvid.stackit.run"
    create_zone                 = false
    zone_id                     = "99999999-8888-7777-6666-555555555555"
    dns_service_account_enabled = false

    wildcard = {
      label   = "cluster1"
      address = "203.0.113.17"
    }
  }

  assert {
    condition     = output.zone_name == "likvid.stackit.run"
    error_message = "with create_zone = false the zone name is the caller's, since there is no zone resource to read it off"
  }

  assert {
    condition     = output.wildcard_domain == "cluster1.likvid.stackit.run"
    error_message = "the label is what keeps the cluster's certificate down to its own names"
  }

  assert {
    condition     = output.dns_service_account_email == null
    error_message = "dns_service_account_enabled = false must create no credential"
  }
}

# The composition switch. This root configures its own provider, so Terraform refuses `count` on it
# and a composition turns it off with a null zone name instead.
run "null_zone_name_switches_the_module_off" {
  command = plan

  variables {
    zone_name                   = null
    create_zone                 = false
    dns_service_account_enabled = false
  }

  assert {
    condition     = output.zone_name == null
    error_message = "a switched-off module must report no zone"
  }

  assert {
    condition     = output.zone_id == null
    error_message = "a switched-off module must neither create nor read a zone"
  }

  assert {
    condition     = output.summary == null
    error_message = "a switched-off module has nothing to summarise"
  }
}

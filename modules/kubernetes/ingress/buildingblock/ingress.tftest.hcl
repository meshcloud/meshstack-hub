# Unit tests for the DNS-01 wildcard certificate. Both providers are mocked, so these tests need
# no cluster, no DNS zone and no ACME account, and they run in seconds.
#
# The values the module hands to Helm carry a sensitivity mark as soon as dns01 is set, because
# var.dns01 is sensitive as a whole. try(nonsensitive(...), ...) unwraps them where the mark is
# present and passes them through where it is not, which is the idiom main.tf already uses.

mock_provider "kubernetes" {}
mock_provider "helm" {}

variables {
  acme_email = "ske@meshcloud.io"
}

run "http01_only_without_dns01" {
  command = plan

  variables {
    dns01 = null
  }

  assert {
    condition     = output.wildcard_certificate_domain == null
    error_message = "Without dns01 there is no wildcard certificate, so the domain has to be null."
  }

  assert {
    condition     = yamldecode(try(nonsensitive(helm_release.issuer.values[0]), helm_release.issuer.values[0])).wildcardCertificate.enabled == false
    error_message = "Without dns01 the chart must not render the wildcard Certificate."
  }
}

# The regression guard that matters most: a caller that sets no certificate_domain has to keep
# rendering *.<zone_name>, exactly as before the attribute existed.
run "certificate_domain_defaults_to_the_zone" {
  command = plan

  variables {
    dns01 = {
      zone_name = "likvid.stackit.run"
      stackit = {
        project_id          = "11111111-2222-3333-4444-555555555555"
        service_account_key = "{}"
      }
    }
  }

  assert {
    condition     = output.wildcard_certificate_domain == "likvid.stackit.run"
    error_message = "A caller that sets no certificate_domain has to get the zone name."
  }

  assert {
    condition     = yamldecode(try(nonsensitive(helm_release.issuer.values[0]), helm_release.issuer.values[0])).wildcardCertificate.domain == "likvid.stackit.run"
    error_message = "The chart has to receive the zone name as the certificate domain, which renders *.likvid.stackit.run."
  }
}

run "certificate_domain_narrows_the_certificate" {
  command = plan

  variables {
    dns01 = {
      zone_name          = "likvid.stackit.run"
      certificate_domain = "cluster1.likvid.stackit.run"
      stackit = {
        project_id          = "11111111-2222-3333-4444-555555555555"
        service_account_key = "{}"
      }
    }
  }

  assert {
    condition     = output.wildcard_certificate_domain == "cluster1.likvid.stackit.run"
    error_message = "The certificate has to cover the domain the caller asked for."
  }

  assert {
    condition     = yamldecode(try(nonsensitive(helm_release.issuer.values[0]), helm_release.issuer.values[0])).wildcardCertificate.domain == "cluster1.likvid.stackit.run"
    error_message = "The chart has to receive the caller's certificate domain, which renders *.cluster1.likvid.stackit.run."
  }

  # The solver still answers for the whole zone. cert-manager matches every name below a zone in
  # the dnsZones selector, so the narrower certificate is issued through the same solver.
  assert {
    condition     = yamldecode(try(nonsensitive(helm_release.issuer.values[0]), helm_release.issuer.values[0])).dns01.zoneName == "likvid.stackit.run"
    error_message = "The ClusterIssuer has to keep the zone in the dnsZones selector of the solver."
  }
}

# The solver only answers for names inside its zone, so a certificate domain outside the zone can
# never be issued. This run also covers the error message itself: var.dns01 is sensitive, so the
# message must not interpolate any part of it.
run "certificate_domain_outside_the_zone_is_rejected" {
  command = plan

  variables {
    dns01 = {
      zone_name          = "likvid.stackit.run"
      certificate_domain = "cluster1.example.com"
      stackit = {
        project_id          = "11111111-2222-3333-4444-555555555555"
        service_account_key = "{}"
      }
    }
  }

  expect_failures = [var.dns01]
}

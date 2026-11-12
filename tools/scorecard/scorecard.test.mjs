import { test } from "node:test";
import assert from "node:assert/strict";
import {
  declaresSummaryOutput,
  explicitDefaultViolations,
  identitiesFromVersions,
  issuerFromPinnedRunner,
  summaryOutputBody,
} from "./scorecard.mjs";

const integration = (argument) => `
variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
    tags = object({
      workspace = map(list(string))
    })
    runner_ref = optional(object({
      kind = optional(string, "meshBuildingBlockRunner")
      uuid = string
    }))
  })
}

resource "meshstack_building_block_definition" "this" {
  version_spec = {
    inputs = {
      some_input = {
        argument = ${argument}
      }
    }
  }
}
`;

test("an argument reading a required attribute of an object with an optional one passes", () => {
  assert.deepEqual(explicitDefaultViolations(integration("jsonencode(var.meshstack.tags.workspace)")), []);
});

test("an argument reading the optional attribute without a variable default fails", () => {
  assert.deepEqual(explicitDefaultViolations(integration("jsonencode(var.meshstack.runner_ref)")), [
    "meshstack (missing default)",
  ]);
});

test("an argument reading the whole object with an optional attribute fails", () => {
  assert.deepEqual(explicitDefaultViolations(integration("jsonencode(var.meshstack)")), [
    "meshstack (missing default)",
  ]);
});

test("a summary output is found past a heredoc with an unpaired quote and a heading", () => {
  const tf = `output "other" {
  value = 1
}

output "summary" {
  value = <<-EOT
    # It's "quoted
    [repo](\${local.repository_url})
  EOT
}

output "after" {
  value = 2
}
`;
  const body = summaryOutputBody(tf);
  assert.match(body, /^output "summary"/);
  assert.match(body, /EOT\n}$/);
  assert.equal(summaryOutputBody(`output "other" {\n  value = 1\n}\n`), null);
});

test("a SUMMARY assignment in the integration is detected", () => {
  assert.equal(declaresSummaryOutput('summary = {\n  assignment_type = "SUMMARY"\n}'), true);
  assert.equal(declaresSummaryOutput('url = {\n  assignment_type = "RESOURCE_URL"\n}'), false);
});

const runnerModule = (source = "github.com/meshcloud/meshstack-hub//modules/meshstack/runner-identity?ref=${var.hub.git_ref}") => `
module "runner" {
  source = "${source}"

  cloud      = "aws"
  runner_ref = var.meshstack.runner_ref
}
`;

const federatedDefinition = ({ issuer, runnerRef }) => `
module "backplane" {
  workload_identity_federation = {
    issuer   = ${issuer}
    subjects = [meshstack_building_block_definition.this.version_latest.workload_identity_federation.subject]
  }
}

resource "meshstack_building_block_definition" "this" {
  version_spec = {
    runner_ref = ${runnerRef}
  }
}
`;

test("an issuer from the runner-identity module the definition pins passes", () => {
  const definition = federatedDefinition({ issuer: "module.runner.issuer", runnerRef: "module.runner.ref" });
  assert.equal(issuerFromPinnedRunner(runnerModule() + definition), true);
  assert.equal(issuerFromPinnedRunner(runnerModule("../../../meshstack/runner-identity") + definition), true);
});

test("an issuer from a runner-identity module the definition does not pin fails", () => {
  const definition = federatedDefinition({ issuer: "module.runner.issuer", runnerRef: "var.meshstack.runner_ref" });
  assert.equal(issuerFromPinnedRunner(runnerModule() + definition), false);
});

test("an issuer from a module that is not runner-identity fails", () => {
  const definition = federatedDefinition({ issuer: "module.runner.issuer", runnerRef: "module.runner.ref" });
  assert.equal(issuerFromPinnedRunner(runnerModule("./runner") + definition), false);
});

test("an issuer from the runner data source passes only when the definition pins that runner", () => {
  const lookup = 'data "meshstack_building_block_runner" "this" {}\n';
  const issuer = "data.meshstack_building_block_runner.this.spec.workload_identity_federation.issuer";
  assert.equal(
    issuerFromPinnedRunner(lookup + federatedDefinition({ issuer, runnerRef: "data.meshstack_building_block_runner.this.ref" })),
    true,
  );
  assert.equal(issuerFromPinnedRunner(lookup + federatedDefinition({ issuer, runnerRef: "var.meshstack.runner_ref" })), false);
});

const trustedRunnersModule = (versions = "meshstack_building_block_definition.this.versions") => `
module "runner" {
  source = "github.com/meshcloud/meshstack-hub//modules/meshstack/runner-identity?ref=\${var.hub.git_ref}"

  cloud               = "aws"
  runner_ref          = var.meshstack.runner_ref
  trusted_runner_refs = var.meshstack.trusted_runner_refs
${versions ? `  versions            = ${versions}\n` : ""}}
`;

const trustedRunnersDefinition = ({ identities = "module.runner.identities", runnerRef = "module.runner.ref" } = {}) => `
module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/aws/s3_bucket/backplane?ref=\${var.hub.git_ref}"

  runner_identities = ${identities}
}

resource "meshstack_building_block_definition" "this" {
  version_spec = {
    runner_ref = ${runnerRef}
  }
}
`;

test("identities from the runner-identity module the definition pins count as its issuer", () => {
  assert.equal(issuerFromPinnedRunner(trustedRunnersModule() + trustedRunnersDefinition()), true);
  assert.equal(
    issuerFromPinnedRunner(trustedRunnersModule() + trustedRunnersDefinition({ runnerRef: "var.meshstack.runner_ref" })),
    false,
  );
});

test("identities pass only when the runner-identity module gets the definition's versions", () => {
  assert.equal(identitiesFromVersions(trustedRunnersModule() + trustedRunnersDefinition()), true);
  assert.equal(identitiesFromVersions(trustedRunnersModule(null) + trustedRunnersDefinition()), false);
  assert.equal(identitiesFromVersions(trustedRunnersModule("{}") + trustedRunnersDefinition()), false);
});

test("identities that are not read from the runner-identity module fail", () => {
  assert.equal(identitiesFromVersions(trustedRunnersModule() + trustedRunnersDefinition({ identities: "local.identities" })), false);
  assert.equal(identitiesFromVersions(runnerModule("./runner") + trustedRunnersDefinition()), false);
  assert.equal(identitiesFromVersions(runnerModule() + federatedDefinition({ issuer: "module.runner.issuer", runnerRef: "module.runner.ref" })), false);
});

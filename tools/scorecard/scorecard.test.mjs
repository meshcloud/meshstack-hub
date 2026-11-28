import { test } from "node:test";
import assert from "node:assert/strict";
import {
  bbdOutputViolations,
  declaresSummaryOutput,
  explicitDefaultViolations,
  identitiesFromVersions,
  issuerFromPinnedRunner,
  meshstackVariableViolation,
  summaryOutputBody,
  summaryStyleViolations,
  supportedPlatformsViolations,
  uuidRefLiterals,
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

test("a summary with a title line, a heading below # or bold text breaks the style", () => {
  assert.deepEqual(summaryStyleViolations("VM `a` is running.\n\n| | |\n|---|---|\n| *Host* | `h` |\n\n# Access\n\nUse SSH.\n"), []);
  assert.deepEqual(summaryStyleViolations("Ready.\n\n```sh\n# a shell comment\n```\n"), []);
  assert.deepEqual(summaryStyleViolations("%{ if x ~}\n# VM\n%{ endif ~}\n"), ["a title line"]);
  assert.deepEqual(summaryStyleViolations("Ready.\n\n## Access\n\nReachable at **h**.\n"), ["a heading below #", "bold text"]);
  assert.deepEqual(summaryStyleViolations("Ready.\n\n> [!TIP]\n> ## Next\n"), ["a heading below #"]);
});

test("a SUMMARY assignment in the integration is detected", () => {
  assert.equal(declaresSummaryOutput('summary = {\n  assignment_type = "SUMMARY"\n}'), true);
  assert.equal(declaresSummaryOutput('url = {\n  assignment_type = "RESOURCE_URL"\n}'), false);
});

const tenantLevel = ({ type = "", supportedPlatforms = "var.meshstack.supported_platforms", targetType = '"TENANT_LEVEL"' } = {}) => `
variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
${type}
  })
}

resource "meshstack_building_block_definition" "this" {
  spec = {
    target_type         = ${targetType}
    supported_platforms = ${supportedPlatforms}
  }
}
`;

const definitionWithOutputs = (outputs) => `
resource "meshstack_building_block_definition" "this" {
  version_spec = {
    inputs = {
      name = {
        assignment_type = "USER_INPUT"
      }
    }
    outputs = ${outputs}
  }
}
`;

const withDefault = `    supported_platforms = optional(list(object({
      kind = optional(string)
      name = optional(string)
      uuid = optional(string)
    })), [{ name = "AZURE" }])`;

const withoutDefault = `    supported_platforms = optional(list(object({
      kind = optional(string)
      name = optional(string)
      uuid = optional(string)
    })))`;

test("a tenant-level definition reading a defaulted meshstack.supported_platforms passes", () => {
  assert.deepEqual(supportedPlatformsViolations(tenantLevel({ type: withDefault })), []);
});

test("a hard-coded platform type fails and names the missing field", () => {
  assert.deepEqual(supportedPlatformsViolations(tenantLevel({ supportedPlatforms: '[{ name = "AZURE" }]' })), [
    "variable meshstack declares no supported_platforms",
    "spec.supported_platforms does not read var.meshstack.supported_platforms",
  ]);
});

test("meshstack.supported_platforms without a default fails", () => {
  assert.deepEqual(supportedPlatformsViolations(tenantLevel({ type: withoutDefault })), [
    "meshstack.supported_platforms has no default",
  ]);
});

test("a required meshstack.supported_platforms passes", () => {
  const required = `    supported_platforms = list(object({
      kind = optional(string)
      name = optional(string)
      uuid = optional(string)
    }))`;
  assert.deepEqual(supportedPlatformsViolations(tenantLevel({ type: required })), []);
});

test("a default computed with coalesce passes without a default in the type", () => {
  const supportedPlatforms = "coalesce(var.meshstack.supported_platforms, [{ kind = null, name = local.platform_type, uuid = null }])";
  assert.deepEqual(supportedPlatformsViolations(tenantLevel({ type: withoutDefault, supportedPlatforms })), []);
});

test("a landing-zone-only definition is checked like any other", () => {
  const tf = tenantLevel({ supportedPlatforms: '[{ name = "STACKIT" }]' }).replace(
    "    supported_platforms =",
    "    use_in_landing_zones_only = true\n    supported_platforms ="
  );
  assert.deepEqual(supportedPlatformsViolations(tf), [
    "variable meshstack declares no supported_platforms",
    "spec.supported_platforms does not read var.meshstack.supported_platforms",
  ]);
});

test("a workspace-level definition is not checked", () => {
  assert.equal(supportedPlatformsViolations(tenantLevel({ targetType: '"WORKSPACE_LEVEL"', supportedPlatforms: "null" })), null);
  assert.equal(supportedPlatformsViolations(tenantLevel({ targetType: "var.link_target_type", supportedPlatforms: "null" })), null);
});

const meshstackVariable = (description) => `
variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
  })
  description = ${description}
}
`;

test("the meshstack variable with the standard description passes", () => {
  assert.equal(meshstackVariableViolation(meshstackVariable('"Shared meshStack context, see docs."')), null);
});

test("an extended or different meshstack description fails", () => {
  const expected = 'description must be exactly "Shared meshStack context, see docs."';
  assert.equal(meshstackVariableViolation(meshstackVariable('"Shared meshStack context, see docs. More."')), expected);
  assert.equal(meshstackVariableViolation(meshstackVariable("<<-EOT\n  Shared meshStack context, see docs.\n  EOT")), expected);
});

test("a module without the meshstack variable fails", () => {
  assert.equal(meshstackVariableViolation('variable "hub" {}'), "no variable meshstack");
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

test("an issuer from a runner data source in the integration fails, also when the definition pins it", () => {
  const lookup = 'data "meshstack_building_block_runner" "this" {}\n';
  const issuer = "data.meshstack_building_block_runner.this.spec.workload_identity_federation.issuer";
  assert.equal(
    issuerFromPinnedRunner(lookup + federatedDefinition({ issuer, runnerRef: "data.meshstack_building_block_runner.this.ref" })),
    false,
  );
});

test("a second definition that does not pin the runner fails", () => {
  const definition = federatedDefinition({ issuer: "module.runner.issuer", runnerRef: "module.runner.ref" });
  const unpinned = `
resource "meshstack_building_block_definition" "other" {
  version_spec = {
    runner_ref = var.meshstack.runner_ref
  }
}
`;
  assert.equal(issuerFromPinnedRunner(runnerModule() + definition + unpinned), false);
});

test("a runner_ref outside a definition does not count as a pin", () => {
  const definition = federatedDefinition({ issuer: "module.runner.issuer", runnerRef: "var.meshstack.runner_ref" });
  const other = `
module "child" {
  runner_ref = module.runner.ref
}
`;
  assert.equal(issuerFromPinnedRunner(runnerModule() + definition + other), false);
});

test("a runner-identity call with a hyphen in its name and a block before source passes", () => {
  const lookup = `
module "runner-identity" {
  providers = {
    meshstack = meshstack
  }
  source = "../../../meshstack/runner-identity/"

  cloud      = "aws"
  runner_ref = var.meshstack.runner_ref
}
`;
  const definition = federatedDefinition({ issuer: "module.runner-identity.issuer", runnerRef: "module.runner-identity.ref" });
  assert.equal(issuerFromPinnedRunner(lookup + definition), true);
});

test("only a building block may build its own tenant's ref from a variable", () => {
  const tenantRef = '{ kind = "meshTenant", uuid = var.tenant_uuid }';
  assert.deepEqual(uuidRefLiterals(tenantRef, true), []);
  assert.equal(uuidRefLiterals(tenantRef, false).length, 1);
  assert.equal(uuidRefLiterals('{ kind = "meshWorkspace", uuid = var.workspace_uuid }', true).length, 1);
  assert.equal(uuidRefLiterals('{ kind = "meshTenant", uuid = meshstack_tenant.this.metadata.uuid }', true).length, 1);
});

const trustedRunnersModule = (versions = "meshstack_building_block_definition.this.versions") => `
module "runner" {
  source = "github.com/meshcloud/meshstack-hub//modules/meshstack/runner-identity?ref=\${var.hub.git_ref}"

  cloud               = "aws"
  runner_ref          = var.meshstack.runner_ref
  additional_trusted_runner_refs = var.meshstack.additional_trusted_runner_refs
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

const summaryAndUrl = `{
      summary = {
        assignment_type = "SUMMARY"
      }
      "console-url" = {
        assignment_type = "RESOURCE_URL"
      }
    }`;

test("BBD outputs declared as plain buildingblock outputs pass", () => {
  const buildingBlock = `
output "summary" {
  value = "done"
}

output "console-url" {
  value = "https://example.com"
}
`;
  assert.deepEqual(bbdOutputViolations(definitionWithOutputs(summaryAndUrl), buildingBlock), []);
});

test("a BBD output missing from the buildingblock or marked sensitive fails", () => {
  const buildingBlock = `
output "summary" {
  value     = "done"
  sensitive = true
}
`;
  assert.deepEqual(bbdOutputViolations(definitionWithOutputs(summaryAndUrl), buildingBlock), [
    "summary (sensitive)",
    "console-url (missing)",
  ]);
});

test("BBD outputs inside merge() are found", () => {
  const outputs = `merge(
      {
        summary = {
          assignment_type = "SUMMARY"
        }
      },
      var.extra_outputs,
    )`;
  assert.deepEqual(bbdOutputViolations(definitionWithOutputs(outputs), ""), ["summary (missing)"]);
});

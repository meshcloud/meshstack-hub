import { test } from "node:test";
import assert from "node:assert/strict";
import {
  declaresSummaryOutput,
  explicitDefaultViolations,
  issuerFromPinnedRunner,
  meshstackVariableViolation,
  summaryOutputBody,
  supportedPlatformsViolations,
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

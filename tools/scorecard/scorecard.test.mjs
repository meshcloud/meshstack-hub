import { test } from "node:test";
import assert from "node:assert/strict";
import {
  countToggleLines,
  declaresSummaryOutput,
  explicitDefaultViolations,
  guaranteesVersion,
  summaryOutputBody,
  usesLifecycleEnabled,
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

test("a count that toggles one instance is found, single-line or split over lines", () => {
  const tf = `resource "a" "one" {
  count = var.enabled ? 1 : 0 # trailing comment
}

data "b" "inverse" {
  count = var.existing == null ? 0 : 1
}

module "split" {
  count = (
    var.enabled
    ? 1
    : 0
  )
  source = "./m"
}

resource "c" "many" {
  count = var.enabled ? length(var.items) : 0
}

resource "d" "length" {
  count = length(var.items)
}
`;
  assert.deepEqual(countToggleLines(tf), [2, 6, 10]);
});

test("lifecycle.enabled is told apart from other lifecycle arguments", () => {
  assert.equal(usesLifecycleEnabled('resource "a" "b" {\n  lifecycle {\n    enabled = var.on\n  }\n}'), true);
  assert.equal(usesLifecycleEnabled('resource "a" "b" {\n  lifecycle {\n    prevent_destroy = true\n  }\n  enabled = true\n}'), false);
});

test("a required_version passes only when its lower bound reaches the floor", () => {
  assert.equal(guaranteesVersion(">= 1.11.0", "1.11.0"), true);
  assert.equal(guaranteesVersion(">= 1.12.0", "1.11.0"), true);
  assert.equal(guaranteesVersion(">=1.11", "1.11.0"), true);
  assert.equal(guaranteesVersion("~> 1.12", "1.11.0"), true);
  assert.equal(guaranteesVersion(">= 1.3.0, < 2.0.0", "1.11.0"), false);
  assert.equal(guaranteesVersion(">= 1.0", "1.11.0"), false);
  assert.equal(guaranteesVersion("< 2.0.0", "1.11.0"), false);
  assert.equal(guaranteesVersion(null, "1.11.0"), false);
});

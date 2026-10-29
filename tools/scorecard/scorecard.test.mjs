import { test } from "node:test";
import assert from "node:assert/strict";
import { bbdOutputViolations, explicitDefaultViolations } from "./scorecard.mjs";

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

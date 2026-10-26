import { test } from "node:test";
import assert from "node:assert/strict";
import { explicitDefaultViolations } from "./scorecard.mjs";

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

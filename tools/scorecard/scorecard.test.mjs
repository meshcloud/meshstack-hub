import { test } from "node:test";
import assert from "node:assert/strict";
import {
  declaresSummaryOutput,
  explicitDefaultViolations,
  summaryLinkViolations,
  summaryOutputBody,
  summaryTemplateFiles,
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

test("the templates a summary renders are listed", () => {
  assert.deepEqual(summaryTemplateFiles('value = templatefile("${path.module}/SUMMARY.md.tftpl", {})'), ["SUMMARY.md.tftpl"]);
});

test("a new-tab anchor passes", () => {
  assert.deepEqual(summaryLinkViolations('<a href="${url}" target="_blank" rel="noopener noreferrer">x</a>'), []);
});

test("Markdown links and anchors without a new tab fail", () => {
  assert.deepEqual(summaryLinkViolations('[a](https://x.io) [b](${local.url}) <a href="y">y</a>'), [
    "Markdown link [a](https://x.io)",
    "Markdown link [b](${local.url})",
    '<a href="y"> lacks target="_blank" and rel="noopener"',
  ]);
});

test("mention tokens and links in a fenced code block pass", () => {
  const markdown = "Runs on @buildingblock[1234] and @project[ws.p].\n\n```md\n[a](https://x.io)\n<a href=\"y\">y</a>\n```\n";
  assert.deepEqual(summaryLinkViolations(markdown), []);
});

test("a SUMMARY assignment in the integration is detected", () => {
  assert.equal(declaresSummaryOutput('summary = {\n  assignment_type = "SUMMARY"\n}'), true);
  assert.equal(declaresSummaryOutput('url = {\n  assignment_type = "RESOURCE_URL"\n}'), false);
});

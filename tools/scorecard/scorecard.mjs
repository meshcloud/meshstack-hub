#!/usr/bin/env node
/**
 * meshstack-hub Module Scorecard
 *
 * Scans every building block module and assesses maturity based on
 * deterministic criteria derived from the repository conventions.
 * Checks are organized into categories with conditional applicability:
 * - Core Structure: applies to all modules
 * - Integration: applies only to modules with meshstack_integration.tf
 * - Azure Backplane: applies only to Azure modules with a backplane/
 * - Shared Practices: modules and reference architectures alike
 * - Reference Architecture: reference architectures only
 * - Testing: applies to all modules (aspirational)
 *
 * A reference architecture is scored with the checks that target it (`targets`) and a summary of
 * the module scorecard of every module it includes. One without code fails every `needsCode` check,
 * so its gaps read as a todo list.
 *
 * Usage: node tools/scorecard/scorecard.mjs [--category=<name>] [--provider=<name>] [--module=<id>] [--fix] [--output=<file>]
 *        node tools/scorecard/scorecard.mjs --ref-archs | --ref-arch=<name> ...
 *        node tools/scorecard/scorecard.mjs --changed-since=<git ref>   modules and reference architectures changed since the ref
 *
 * It exits non-zero only on a script error, never on failing checks.
 */

import { execFileSync } from "node:child_process";
import { readFileSync, writeFileSync, existsSync, readdirSync, statSync } from "node:fs";
import { basename, dirname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = new URL("../../", import.meta.url).pathname.replace(/\/$/, "");
const MODULES_DIR = join(ROOT, "modules");
const REF_ARCHS_DIR = join(ROOT, "reference-architectures");

const byCodeUnits = (a, b) => (a < b ? -1 : Number(a > b));

// A building block definition's terraform_version selects a HashiCorp Terraform binary up to
// 1.5.5 and an OpenTofu one above it. 1.10.0 is where OpenTofu started short-circuiting && and
// ||, so anything below it faults on the common `var.x == null || var.x.attr` guard.
const TERRAFORM_VERSION_FLOOR = "1.12.0";

// Our own provider is still on 0.x, where a minor release is what carries breaking changes, so a
// `< 1.0.0` bound would buy nothing. It is exempt from the upper-bound rule until it reaches 1.0.
const MAJOR_UNSTABLE_PROVIDER = "meshcloud/meshstack";

// Every meshStack object that can be pointed at exposes a `ref` output shaped exactly like the
// attribute that points to it, `kind` included. Rebuilding that object from `metadata.uuid` or
// `metadata.name` repeats what the provider already knows and usually drops the `kind`, so a
// reference to the wrong kind of object only surfaces when meshStack rejects the apply.
// Regenerate with: tofu providers schema -json | jq '.provider_schemas[]
//   | .resource_schemas | to_entries[] | select(.value.block.attributes.ref) | .key'
const MESHSTACK_REF_RESOURCES = new Set([
  "meshstack_building_block",
  "meshstack_building_block_definition",
  "meshstack_building_block_runner",
  "meshstack_integration",
  "meshstack_landingzone",
  "meshstack_location",
  "meshstack_platform",
  "meshstack_platform_type",
  "meshstack_tenant",
  "meshstack_workspace",
]);

// A building block is ordered against a definition *version*, which `ref` does not identify —
// these two outputs are the ref-shaped values for that.
const BBD_VERSION_REF_OUTPUTS = new Set(["version_latest", "version_latest_release"]);

const compareVersions = (a, b) => {
  const pa = a.split(".").map(Number);
  const pb = b.split(".").map(Number);
  for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
    const d = (pa[i] ?? 0) - (pb[i] ?? 0);
    if (d !== 0) return d;
  }
  return 0;
};

// ─── Category definitions ───────────────────────────────────────────────────

const CATEGORIES = {
  core: {
    id: "core",
    name: "Core Structure",
    description: "Basic module file structure and documentation",
    appliesTo: () => true,
  },
  integration: {
    id: "integration",
    name: "Integration",
    description: "meshstack_integration.tf conventions",
    appliesTo: (mod) => existsSync(join(mod.path, "meshstack_integration.tf")),
  },
  aws_backplane: {
    id: "aws_backplane",
    name: "AWS Backplane",
    description: "AWS automation principal conventions (WIF or cross-account StackSet)",
    // A backplane/ holding no .tf files of its own declares no automation principal — the
    // agentic-coding-sandbox composition keeps only a landingzone/ submodule there — so the
    // category does not apply to it.
    appliesTo: (mod) => mod.provider === "aws" && readAllBackplaneTf(mod) !== null,
  },
  azure_backplane: {
    id: "azure_backplane",
    name: "Azure Backplane",
    description: "Azure UAMI-based automation principal conventions",
    appliesTo: (mod) =>
      mod.provider === "azure" && existsSync(join(mod.path, "backplane")),
  },
  gcp_backplane: {
    id: "gcp_backplane",
    name: "GCP Backplane",
    description: "GCP workload-identity-federation automation principal conventions",
    appliesTo: (mod) =>
      mod.provider === "gcp" && existsSync(join(mod.path, "backplane")),
  },
  stackit_backplane: {
    id: "stackit_backplane",
    name: "STACKIT Backplane",
    description: "STACKIT WIF-based automation principal conventions",
    appliesTo: (mod) =>
      mod.provider === "stackit" && existsSync(join(mod.path, "backplane")),
  },
  shared: {
    id: "shared",
    name: "Shared Practices",
    description: "Practices modules and reference architectures share",
    appliesTo: () => true,
  },
  ref_arch: {
    id: "ref_arch",
    name: "Reference Architecture",
    description: "How a reference architecture orders and documents its building blocks",
    appliesTo: () => true,
  },
  testing: {
    id: "testing",
    name: "Testing",
    description: "End-to-end test coverage",
    appliesTo: () => true,
  },
};

// AWS backplanes come in two documented identity patterns, and most checks belong to exactly one:
//   "wif"           — OIDC provider + IAM role, for a building block acting in a single account
//   "cross_account" — IAM user + assumable role (usually distributed by a StackSet), for org-wide
//                     building blocks that must reach every account in an OU
// A backplane carrying federation machinery is classified "wif" even when it also mints an access
// key: that hybrid is the optional-WIF-with-key-fallback shape the reference forbids, and
// aws_wif_no_access_key is what reports it. Everything else that mints a key is cross-account.
function awsBackplanePattern(mod) {
  const allTf = readAllBackplaneTf(mod);
  if (!allTf) return "none";
  const federated =
    /(resource|data)\s+"aws_iam_openid_connect_provider"/.test(allTf) ||
    /^variable\s+"(workload_identity_federation|oidc_provider_arn)"/m.test(allTf);
  if (federated) return "wif";
  return /resource\s+"aws_iam_access_key"/.test(allTf) ? "cross_account" : "none";
}

// The fixed notice on `oidc_provider_arn` / `aws_oidc_provider_arn`. Deliberately two lines and
// nothing more, so it can be copied verbatim into every meshstack_integration.tf.
const AWS_OIDC_PROVIDER_NOTICE = [
  "ARN of the IAM OIDC provider for the meshStack runner WIF token issuer in this AWS account.",
  "See .agents/references/aws-backplane.md#the-shared-oidc-provider",
];

function hasOidcProviderNotice(variableBlock) {
  const text = variableBlock.replace(/\s+/g, " ");
  return AWS_OIDC_PROVIDER_NOTICE.every((line) => text.includes(line.replace(/\s+/g, " ")));
}

const NOT_WIF = { pass: null, detail: "not a workload identity federation backplane" };
const NOT_CROSS_ACCOUNT = { pass: null, detail: "not a cross-account backplane" };

// The STACKIT provider derives its whole WIF credential from these, so a buildingblock needs no
// auth arguments in its provider block. See .agents/references/stackit-backplane.md.
const STACKIT_WIF_ENV_VARS = [
  "STACKIT_SERVICE_ACCOUNT_EMAIL",
  "STACKIT_USE_OIDC",
  "STACKIT_FEDERATED_TOKEN_FILE",
];

// ─── Detector functions ─────────────────────────────────────────────────────
// Each detector returns { pass: boolean, detail?: string }

const detectors = [
  // ─── Core Structure ─────────────────────────────────────────────────────
  {
    id: "buildingblock_dir",
    category: "core",
    name: "buildingblock/ directory exists",
    emoji: "📦",
    fn: (mod) => ({
      pass: existsSync(join(mod.path, "buildingblock")),
    }),
  },
  {
    id: "meshstack_integration",
    category: "core",
    name: "meshstack_integration.tf present",
    emoji: "🔗",
    fn: (mod) => ({
      pass: existsSync(join(mod.path, "meshstack_integration.tf")),
    }),
  },
  {
    id: "app_team_readme",
    category: "core",
    name: "buildingblock/APP_TEAM_README.md present (no-integration fallback)",
    emoji: "📋",
    fn: (mod) => {
      // Modules with a meshstack_integration.tf carry their readme inline — no fallback file needed.
      if (existsSync(join(mod.path, "meshstack_integration.tf"))) {
        return { pass: null, detail: "not applicable — readme is inline in integration file" };
      }
      return {
        pass: existsSync(join(mod.path, "buildingblock", "APP_TEAM_README.md")),
        detail: "missing — modules without meshstack_integration.tf need buildingblock/APP_TEAM_README.md as user-facing readme fallback",
      };
    },
  },
  {
    id: "readme_frontmatter",
    category: "core",
    name: "buildingblock/README.md with YAML front-matter",
    emoji: "📝",
    fn: (mod) => {
      const readmePath = join(mod.path, "buildingblock", "README.md");
      if (!existsSync(readmePath)) return { pass: false, detail: "missing" };
      const content = readFileSync(readmePath, "utf-8");
      const hasFrontmatter = content.startsWith("---");
      const hasName = /^name:/m.test(content);
      const hasPlatforms = /^supportedPlatforms:/m.test(content);
      const hasDescription = /^description:/m.test(content);
      return {
        pass: hasFrontmatter && hasName && hasPlatforms && hasDescription,
        detail: !hasFrontmatter ? "no front-matter" : "missing required fields",
      };
    },
  },
  {
    id: "logo",
    category: "core",
    name: "buildingblock/logo.png or logo.svg included",
    emoji: "🖼️",
    fn: (mod) => ({
      pass: ["logo.png", "logo.svg"].some((logo) => existsSync(join(mod.path, "buildingblock", logo))),
    }),
  },
  {
    id: "versions_tf",
    category: "core",
    name: "buildingblock/versions.tf present",
    emoji: "📌",
    fn: (mod) => {
      if (!runsTerraform(mod)) return { pass: null, detail: "not applicable — non-terraform implementation" };
      return { pass: existsSync(join(mod.path, "buildingblock", "versions.tf")) };
    },
  },
  {
    id: "child_bb_run_postcondition",
    category: "core",
    name: "Child meshstack_building_block asserts a SUCCEEDED run",
    emoji: "🚦",
    fn: (mod) => {
      const offenders = [];
      let ordered = 0;

      for (const file of collectTfFilesRecursive(join(mod.path, "buildingblock"))) {
        const content = readFileSync(file, "utf-8");
        for (const [name, body] of extractResourceBlocks(content, "meshstack_building_block")) {
          ordered++;
          const where = `${relative(mod.path, file)}: ${name}`;
          const postcondition = findRunStatusPostcondition(body);
          if (!postcondition) {
            offenders.push(`${where} — no postcondition on self.status.succeeded`);
          } else if (!/error_message\s*=[^\n]*self\.status\.health_status[^\n]*self\.status\.action/.test(postcondition)) {
            offenders.push(`${where} — error_message does not name self.status.health_status and self.status.action`);
          }
          if (postcondition && /wait_for_completion\s*=\s*false/.test(body)) {
            offenders.push(`${where} — wait_for_completion = false, so the run is still PENDING when the postcondition is checked`);
          }
        }
      }

      if (ordered === 0) return { pass: null, detail: "orders no child building blocks" };
      if (offenders.length === 0) return { pass: true };
      return {
        pass: false,
        detail: `${offenders.join("; ")} — see .agents/references/meshstack-resources.md, "Ordering Child Building Blocks"`,
      };
    },
  },
  {
    id: "meshstack_ref_output",
    category: "shared",
    name: "meshStack `*_ref` attributes take a ref, never an object built from a uuid",
    emoji: "🎯",
    targets: ["module", "refArch"],
    needsCode: true,
    fn: (mod) => {
      const offenders = [];
      let references = 0;

      // Whole module, not just the two tiers: the integration file and the e2e fixtures write
      // meshStack resources too, and a fixture is where a hand-built ref hides longest.
      for (const file of collectTfFilesRecursive(mod.path)) {
        const content = blankHeredocBodies(readFileSync(file, "utf-8"));
        for (const [address, body] of extractMeshstackResourceBlocks(content)) {
          const iterated = body.match(/for_each\s*=\s*(meshstack_[a-z_0-9]+)\./)?.[1];

          for (const [attribute, expression] of extractRefAttributes(body)) {
            references++;
            const where = `${relative(mod.path, file)}: ${address}.${attribute}`;
            for (const handRolled of handRolledRefs(expression, iterated)) {
              offenders.push(`${where} reads ${handRolled}`);
            }
            for (const literal of uuidRefLiterals(expression)) {
              offenders.push(`${where} builds ${literal} from a uuid`);
            }
          }
        }
      }

      if (references === 0)
        return { pass: null, detail: "no *_ref attributes on meshStack resources" };
      if (offenders.length === 0) return { pass: true };

      const shown = offenders.slice(0, 4).join("; ");
      const more = offenders.length > 4 ? `, +${offenders.length - 4} more` : "";
      return { pass: false, detail: `take a ref-typed variable or the resource's \`ref\` output: ${shown}${more}` };
    },
  },
  {
    id: "try_explained",
    category: "core",
    name: "Every try() carries a comment saying why",
    emoji: "🩹",
    fn: (mod) => {
      const offenders = [];
      let guards = 0;

      for (const file of collectTfFilesRecursive(mod.path)) {
        const lines = blankHeredocBodies(readFileSync(file, "utf-8")).split("\n");
        lines.forEach((line, index) => {
          if (isCommentLine(line) || !/\btry\s*\(/.test(line)) return;
          guards++;
          if (!hasCommentAbove(lines, index))
            offenders.push(`${relative(mod.path, file)}:${index + 1}`);
        });
      }

      if (guards === 0) return { pass: null, detail: "module uses no try()" };
      if (offenders.length === 0) return { pass: true };

      const shown = offenders.slice(0, 6).join(", ");
      const more = offenders.length > 6 ? `, +${offenders.length - 6} more` : "";
      return { pass: false, detail: `say what each try() swallows and why: ${shown}${more}` };
    },
  },
  {
    id: "prerun_no_global_install",
    category: "core",
    name: "Pre-run scripts install no tools on the runner",
    emoji: "🧼",
    fn: (mod) => {
      const offenders = [];
      const scripts = collectFilesRecursive(mod.path).filter((file) => /^prerun\./.test(basename(file)));

      for (const file of scripts) {
        readFileSync(file, "utf-8").split("\n").forEach((line, index) => {
          if (/\bnix\s+profile\s+(add|install)\b|\bnix-env\b.*\s(-[A-Za-z]*i[A-Za-z]*|--install)\b/.test(line)) {
            offenders.push(`${relative(mod.path, file)}:${index + 1}`);
          }
        });
      }

      if (scripts.length === 0) return { pass: null, detail: "no pre-run script" };
      if (offenders.length === 0) return { pass: true };
      return {
        pass: false,
        detail:
          `installs into a nix profile, which changes the runner host (${offenders.join(", ")}). ` +
          "Current recommendation: a flake in buildingblock/nix/ and Terraform calling `nix shell ./nix#<tool> --command …`. " +
          "Found a better way? Use it and update .agents/references/module-layout.md#pre-run-scripts",
      };
    },
  },
  {
    id: "flake_used_by_terraform",
    category: "core",
    name: "A module flake sits in nix/, is pinned, and Terraform calls it",
    emoji: "❄️",
    fn: (mod) => {
      const flakeDirs = new Set(
        collectFilesRecursive(mod.path)
          .filter((file) => ["flake.nix", "flake.lock"].includes(basename(file)))
          .map((file) => dirname(file)),
      );
      if (flakeDirs.size === 0) return { pass: null, detail: "module has no flake" };

      const problems = [];
      for (const dir of flakeDirs) {
        const where = relative(mod.path, dir) || ".";
        if (basename(dir) !== "nix") {
          problems.push(
            `${where}: flake outside a nix/ folder, so nix shell copies the whole working directory, secrets included, into the world-readable nix store`,
          );
          continue;
        }
        if (!existsSync(join(dir, "flake.nix"))) problems.push(`${where}: flake.lock without flake.nix`);
        else if (!existsSync(join(dir, "flake.lock"))) problems.push(`${where}: flake.nix without flake.lock, so nixpkgs is unpinned`);

        const tfDir = dirname(dir);
        const callsFlake = readdirSync(tfDir)
          .filter((entry) => entry.endsWith(".tf"))
          .some((entry) => /\bnix\b["',\s]+shell\b["',\s]+(path:)?\.\/nix#/.test(readFileSync(join(tfDir, entry), "utf-8")));
        if (!callsFlake) problems.push(`${where}: no .tf file in its parent calls \`nix shell ./nix#…\`, so the flake is unused`);
      }

      if (problems.length === 0) return { pass: true };
      return {
        pass: false,
        detail:
          `${problems.join("; ")}. A module flake lives in nix/ next to the .tf files and gives Terraform its tools through ` +
          "`nix shell ./nix#<tool> --command …` — see .agents/references/module-layout.md#pre-run-scripts",
      };
    },
  },
  {
    id: "provider_pinned",
    category: "core",
    name: "Provider versions float within one major (>= X.Y.Z, < N.0.0)",
    emoji: "🔒",
    fn: (mod) => {
      const constraints = collectProviderConstraints(mod);
      if (constraints.length === 0)
        return { pass: true, detail: "no provider version constraints" };

      const violations = [];
      for (const c of constraints) {
        if (!c.constraint.includes(">=") || c.constraint.includes("~>")) {
          violations.push({ ...c, why: "needs a >= floor" });
        } else if (!c.constraint.includes("<") && c.source !== MAJOR_UNSTABLE_PROVIDER) {
          violations.push({ ...c, why: "needs a < upper bound on the next major" });
        }
      }
      if (violations.length === 0) return { pass: true };

      const shown = violations
        .slice(0, 4)
        .map((v) => `${v.file}: ${v.provider} = "${v.constraint}" (${v.why})`)
        .join(", ");
      const more = violations.length > 4 ? `, +${violations.length - 4} more` : "";
      return {
        pass: false,
        detail: `use \`>= X.Y.Z, < N.0.0\`: ${shown}${more}`,
      };
    },
  },

  // ─── Integration ────────────────────────────────────────────────────────
  {
    id: "variable_hub",
    category: "integration",
    name: 'variable "hub" in integration',
    emoji: "🏷️",
    fn: (mod) => {
      const content = readIntegrationTf(mod);
      if (!content) return { pass: false, detail: "no integration file" };
      return { pass: /variable\s+"hub"/.test(content) };
    },
  },
  {
    id: "variable_meshstack",
    category: "integration",
    name: 'variable "meshstack" in integration',
    emoji: "🏢",
    fn: (mod) => {
      const content = readIntegrationTf(mod);
      if (!content) return { pass: false, detail: "no integration file" };
      return { pass: /variable\s+"meshstack"/.test(content) };
    },
  },
  {
    id: "output_bbd",
    category: "integration",
    name: "building_block_definition output exposed",
    emoji: "📤",
    fn: (mod) => {
      const content = readIntegrationTf(mod);
      if (!content) return { pass: false, detail: "no integration file" };
      return {
        pass: /output\s+"building_block_definition"/.test(content),
      };
    },
  },
  {
    id: "required_providers_meshstack",
    category: "integration",
    name: "meshcloud/meshstack in required_providers",
    emoji: "🔌",
    fn: (mod) => {
      const content = readIntegrationTf(mod);
      if (!content) return { pass: false, detail: "no integration file" };
      return {
        pass: /meshcloud\/meshstack/.test(content),
      };
    },
  },
  {
    id: "backplane_source_hub_git_ref",
    category: "integration",
    name: "backplane source uses var.hub.git_ref",
    emoji: "📎",
    fn: (mod) => {
      const content = readIntegrationTf(mod);
      if (!content) return { pass: false, detail: "no integration file" };
      const hasBackplaneSource = /source\s*=\s*"[^"]*\/backplane[^"]*"/.test(content);
      if (!hasBackplaneSource) return { pass: true, detail: "no backplane module" };
      return {
        pass: /source\s*=\s*"[^"]*\/backplane[^"]*\$\{var\.hub\.git_ref\}[^"]*"/.test(content),
        detail: "backplane source has hardcoded ref instead of var.hub.git_ref",
      };
    },
  },
  {
    id: "ref_name_hub_git_ref",
    category: "integration",
    name: "ref_name uses var.hub.git_ref",
    emoji: "🔀",
    fn: (mod) => {
      const content = readIntegrationTf(mod);
      if (!content) return { pass: false, detail: "no integration file" };

      // A pipeline implementation points ref_name at a branch in the customer's own repository, so
      // pinning it to the hub release would be wrong.
      if (!runsTerraform(mod)) return { pass: null, detail: "not applicable — non-terraform implementation" };

      const hasRefName = /ref_name\s*=/.test(content);
      if (!hasRefName) return { pass: false, detail: "no ref_name found" };
      return { pass: /ref_name\s*=\s*var\.hub\.git_ref/.test(content) };
    },
  },
  {
    id: "bbd_terraform_version_floor",
    category: "integration",
    name: `BBD terraform_version >= ${TERRAFORM_VERSION_FLOOR}`,
    emoji: "🌱",
    fn: (mod) => {
      const content = readIntegrationTf(mod);
      if (!content) return { pass: false, detail: "no integration file" };

      if (!runsTerraform(mod)) return { pass: null, detail: "not applicable — non-terraform implementation" };

      const found = [...content.matchAll(/terraform_version\s*=\s*"([^"]+)"/g)].map((m) => m[1]);
      if (found.length === 0) {
        return { pass: false, detail: `terraform_version not set — pin "${TERRAFORM_VERSION_FLOOR}" or newer` };
      }

      const stale = found.filter((v) => compareVersions(v, TERRAFORM_VERSION_FLOOR) < 0);
      if (stale.length === 0) return { pass: true };

      return {
        pass: false,
        detail: `${[...new Set(stale)].join(", ")} predates the hub floor ${TERRAFORM_VERSION_FLOOR}`,
      };
    },
  },
  {
    id: "bbd_draft",
    category: "integration",
    name: "version_spec.draft uses var.hub.bbd_draft",
    emoji: "📋",
    fn: (mod) => {
      const content = readIntegrationTf(mod);
      if (!content) return { pass: false, detail: "no integration file" };
      return { pass: /draft\s*=\s*var\.hub\.bbd_draft/.test(content) };
    },
  },
  {
    id: "bbd_tags_forwarded",
    category: "integration",
    name: "BBD metadata.tags forwards var.meshstack.tags",
    emoji: "🏷️",
    fn: (mod) => {
      const content = readIntegrationTf(mod);
      if (!content) return { pass: false, detail: "no integration file" };
      return { pass: /tags\s*=\s*var\.meshstack\.tags/.test(content) };
    },
  },
  {
    id: "bbd_inputs_explicit_defaults",
    category: "integration",
    name: "BBD input argument vars with optional() have explicit defaults",
    emoji: "🧱",
    fn: (mod) => {
      const content = readIntegrationTf(mod);
      if (!content) return { pass: false, detail: "no integration file" };

      const bbdResources = extractBBDResourceBlocks(content);
      if (bbdResources.length === 0) {
        return { pass: null, detail: "no meshstack_building_block_definition resource" };
      }

      const violations = explicitDefaultViolations(content);
      if (violations.length === 0) return { pass: true };

      const shown = violations.slice(0, 5).join(", ");
      const more = violations.length > 5 ? ` (+${violations.length - 5} more)` : "";
      return {
        pass: false,
        detail: `set explicit defaults for vars referenced by BBD input arguments: ${shown}${more}`,
      };
    },
  },
  {
    id: "bbd_catalog_overrides",
    category: "integration",
    name: "BBD catalog properties are overridable",
    emoji: "🏪",
    fn: (mod) => {
      const content = readIntegrationTf(mod);
      if (!content) return { pass: false, detail: "no integration file" };

      const resources = extractBBDResourceBlocks(content);
      if (resources.length === 0) {
        return { pass: null, detail: "no meshstack_building_block_definition resource" };
      }

      const declaredVariables = extractVariableBlocks(content);
      const hardcoded = new Set();

      for (const resourceBlock of resources) {
        for (const attribute of ["display_name", "description", "readme"]) {
          const variable = specOverrideVariable(resourceBlock, attribute);
          if (variable === null || !declaredVariables.has(variable)) hardcoded.add(attribute);
        }
      }

      if (hardcoded.size === 0) return { pass: true };
      return {
        pass: false,
        detail: `wrap in coalesce(var.bbd_<field>, <the module's own text>) so a consumer can override: ${[...hardcoded].join(", ")}`,
      };
    },
  },
  {
    id: "bbd_readme",
    category: "integration",
    name: "BBD readme field present",
    emoji: "📖",
    fn: (mod) => {
      const content = readIntegrationTf(mod);
      if (!content) return { pass: false, detail: "no integration file" };
      return { pass: /readme\s*=/.test(content) };
    },
  },
  {
    id: "bbd_readme_no_leading_heading",
    category: "integration",
    name: "BBD readme starts with plain-text description (no heading)",
    emoji: "📝",
    fn: (mod) => {
      const content = readIntegrationTf(mod);
      if (!content) return { pass: false, detail: "no integration file" };
      const readmeContent = extractBBDReadmeContent(content);
      if (readmeContent === null) return { pass: false, detail: "readme is not a heredoc — use chomp(<<-EOT)" };
      if (readmeContent === "") return { pass: false, detail: "readme is empty" };
      return {
        pass: !readmeContent.startsWith("#"),
        detail: "readme starts with a heading — begin with plain-text description instead",
      };
    },
  },
  {
    id: "bbd_readme_shared_responsibility",
    category: "integration",
    name: "BBD readme has shared responsibility table (✅/❌)",
    emoji: "📊",
    fn: (mod) => {
      const content = readIntegrationTf(mod);
      if (!content) return { pass: false, detail: "no integration file" };
      if (!/readme\s*=/.test(content)) return { pass: false, detail: "no readme field" };
      const hasTableSeparator = /\|[ :]*-+[ :]*\|/.test(content);
      const hasCheckEmoji = /[✅❌]/.test(content);
      return {
        pass: hasTableSeparator && hasCheckEmoji,
        detail: !hasCheckEmoji
          ? "no ✅/❌ emojis found — add a shared responsibility table"
          : "no markdown table separator found — ensure table uses |---|:---:| rows",
      };
    },
  },
  {
    id: "no_documentation_md_output",
    category: "integration",
    name: "No documentation_md output in backplane",
    emoji: "🚫",
    fn: (mod) => {
      const allTf = readAllBackplaneTf(mod);
      if (!allTf) return { pass: true, detail: "no backplane" };
      return {
        pass: !/output\s+"documentation_md"/.test(allTf),
        detail: "legacy documentation_md output found — move content to BBD readme and backplane/README.md",
      };
    },
  },
  {
    id: "platform_lifecycle_ignore_availability",
    category: "integration",
    name: "meshstack_platform has lifecycle ignore_changes = [availability]",
    emoji: "🔄",
    fn: (mod) => {
      const content = readIntegrationTf(mod);
      if (!content) return { pass: false, detail: "no integration file" };
      const hasPlatformResource = /resource\s+"meshstack_platform"/.test(content);
      if (!hasPlatformResource) return { pass: null, detail: "no meshstack_platform resource" };
      return {
        pass: /lifecycle\s*\{[\s\S]*?ignore_changes\s*=\s*\[[^\]]*spec\.availability[^\]]*\]/.test(content),
        detail: "add lifecycle { ignore_changes = [spec.availability] } to meshstack_platform resource",
      };
    },
  },
  {
    id: "wif_no_replicator",
    category: "integration",
    name: "Trusts the runner's identity, not the replicator's",
    emoji: "🪪",
    // Only a building block module is scanned here. The platform-level
    // modules/<cloud>/meshstack_integration.tf files are not modules in this sense and keep
    // reading the replicator entry, which is what they exist to configure. buildingblock/ is
    // scanned as well, because a run that federates other definitions builds its trust there.
    fn: (mod) => {
      const buildingBlock = readAllBuildingBlockTf(mod);
      if (buildingBlock && /workload_identity_federation\.replicator/.test(buildingBlock))
        return {
          pass: false,
          detail: "buildingblock/ derives a trust from data.meshstack_integrations…replicator; read each definition's identity from data.meshstack_building_block_definitions, which follows the definition's runner",
        };
      const content = readIntegrationTf(mod);
      if (!content) return { pass: false, detail: "no integration file" };
      if (/workload_identity_federation\.replicator/.test(content))
        return {
          pass: false,
          detail: "derives the runner's trust from data.meshstack_integrations…replicator — that entry is the replicator's own identity and only ever matched because the runner shares its namespace",
        };
      if (!/workload_identity_federation\s*=/.test(content)) return { pass: null, detail: "module does not federate" };
      // The runner's resolved identity lives on the definition's version, exposed by the provider as
      // version_latest / version_latest_release — there is no status.workload_identity_federation
      // attribute. See meshstack-integration.md § Runner identity.
      if (!/version_latest(?:_release)?\.workload_identity_federation\.issuer/.test(content))
        return { pass: false, detail: "issuer is not taken from meshstack_building_block_definition.<name>.version_latest.workload_identity_federation.issuer, which follows the runner the definition runs on" };
      return {
        pass: /version_latest(?:_release)?\.workload_identity_federation\.subject/.test(content),
        detail: "subjects are not taken from meshstack_building_block_definition.<name>.version_latest.workload_identity_federation.subject, so the backplane may trust something the runner never presents",
      };
    },
  },

  // ─── AWS Backplane ──────────────────────────────────────────────────────
  // AWS documents two legitimate identity patterns, so a check has to know which one a backplane
  // implements before it can judge it. Pattern B mints an `aws_iam_access_key` on purpose, so a
  // blanket "no access key" check would be wrong there — it only applies on the federation path.
  {
    id: "aws_wif_external_oidc_provider",
    category: "aws_backplane",
    name: "Takes oidc_provider_arn instead of creating a provider",
    emoji: "🔐",
    fn: (mod) => {
      if (awsBackplanePattern(mod) !== "wif") return NOT_WIF;
      const allTf = readAllBackplaneTf(mod);
      if (/resource\s+"aws_iam_openid_connect_provider"/.test(allTf)) {
        return {
          pass: false,
          detail: "creates its own aws_iam_openid_connect_provider — AWS registers one per issuer URL per account, so it is shared platform infrastructure a backplane must be given, not claim",
        };
      }
      const varsTf = readBackplaneFile(mod, "variables.tf");
      const arnVar = varsTf ? extractVariableBlocks(varsTf).get("oidc_provider_arn") : null;
      if (!arnVar) return { pass: false, detail: 'missing variable "oidc_provider_arn"' };
      if (/^\s*default\s*=/m.test(arnVar))
        return { pass: false, detail: "oidc_provider_arn has a default — the provider has to be deployed first, so there is nothing sensible to default to" };
      if (/^variable\s+"create_oidc_provider"/m.test(allTf))
        return { pass: false, detail: "leftover create_oidc_provider variable — the toggle is gone with the resource" };
      return {
        pass: /nullable\s*=\s*false/.test(arnVar),
        detail: "oidc_provider_arn is not nullable = false",
      };
    },
  },
  {
    id: "aws_oidc_provider_notice",
    category: "aws_backplane",
    name: "oidc_provider_arn carries the shared-provider notice",
    emoji: "📌",
    fn: (mod) => {
      if (awsBackplanePattern(mod) !== "wif") return NOT_WIF;
      // The notice is the only signpost a first-time platform engineer gets: AWS has no plural
      // OIDC-provider data source, so a missing provider cannot be turned into a friendly
      // precondition, and terraform-docs renders backplane variables but not integration comments.
      // It is therefore copied verbatim into both variables and linted here.
      const varsTf = readBackplaneFile(mod, "variables.tf");
      const backplaneVar = varsTf ? extractVariableBlocks(varsTf).get("oidc_provider_arn") : null;
      if (!backplaneVar) return { pass: false, detail: 'missing variable "oidc_provider_arn"' };
      if (!hasOidcProviderNotice(backplaneVar))
        return { pass: false, detail: "backplane oidc_provider_arn description is not the fixed notice — see AWS_OIDC_PROVIDER_NOTICE in this file" };

      const integration = readIntegrationTf(mod);
      if (!integration) return { pass: null, detail: "no integration file" };
      const integrationVar = extractVariableBlocks(integration).get("aws_oidc_provider_arn");
      if (!integrationVar) return { pass: false, detail: 'integration is missing variable "aws_oidc_provider_arn"' };
      return {
        pass: hasOidcProviderNotice(integrationVar),
        detail: "integration aws_oidc_provider_arn description is not the fixed notice",
      };
    },
  },
  {
    id: "aws_wif_no_access_key",
    category: "aws_backplane",
    name: "No aws_iam_access_key on the federation path",
    emoji: "🚫",
    fn: (mod) => {
      if (awsBackplanePattern(mod) !== "wif") return NOT_WIF;
      const allTf = readAllBackplaneTf(mod);
      return {
        pass: !/resource\s+"aws_iam_access_key"/.test(allTf),
        detail: "aws_iam_access_key alongside workload identity federation — a long-lived key fallback is not a supported path for a single-account building block",
      };
    },
  },
  {
    id: "aws_wif_nonnullable",
    category: "aws_backplane",
    name: "workload_identity_federation is non-nullable",
    emoji: "⚡",
    fn: (mod) => {
      if (awsBackplanePattern(mod) !== "wif") return NOT_WIF;
      const varsTf = readBackplaneFile(mod, "variables.tf");
      if (!varsTf) return { pass: false, detail: "no variables.tf" };
      const wifVar = extractVariableBlocks(varsTf).get("workload_identity_federation");
      if (!wifVar) return { pass: false, detail: 'variable "workload_identity_federation" not found' };
      const hasDefaultNull = /default\s*=\s*null/.test(wifVar);
      return {
        pass: /nullable\s*=\s*false/.test(wifVar) || !hasDefaultNull,
        detail: hasDefaultNull
          ? "default = null makes federation optional — the null branch is the access key path"
          : undefined,
      };
    },
  },
  {
    id: "aws_wif_subject_condition",
    category: "aws_backplane",
    name: "Trust policy scopes :sub to the BBD's WIF subjects",
    emoji: "🛂",
    fn: (mod) => {
      if (awsBackplanePattern(mod) !== "wif") return NOT_WIF;
      const allTf = readAllBackplaneTf(mod);
      // The condition variable is a template carrying nested quotes —
      // `"${trimprefix(var....issuer, "https://")}:sub"` — so match to end of line, not to the
      // next quote.
      const hasSubCondition = /^\s*variable\s*=.*:sub"/m.test(allTf);
      const hasSubjects = /var\.workload_identity_federation\.subjects/.test(allTf);
      if (!hasSubCondition)
        return { pass: false, detail: "no :sub condition — the role is assumable by every subject the meshStack issuer signs" };
      if (!hasSubjects)
        return { pass: false, detail: "the :sub condition does not use var.workload_identity_federation.subjects, so it is not scoped to this building block definition" };
      // A subject list the integration built from strings scopes nothing the runner guarantees.
      const integration = readIntegrationTf(mod);
      if (!integration) return { pass: true };
      return {
        pass: /subjects\s*=\s*\[[^\]]*status\.workload_identity_federation\.subject/.test(integration),
        detail: "the integration does not pass the definition's resolved subject — see .agents/references/meshstack-integration.md#runner-identity",
      };
    },
  },
  {
    id: "aws_wif_role_output",
    category: "aws_backplane",
    name: "Outputs workload_identity_federation_role as a constructed ARN",
    emoji: "📤",
    fn: (mod) => {
      if (awsBackplanePattern(mod) !== "wif") return NOT_WIF;
      const outputsTf = readBackplaneFile(mod, "outputs.tf");
      if (!outputsTf) return { pass: false, detail: "no outputs.tf" };
      const blocks = extractOutputBlocks(outputsTf);
      const roleOutput = blocks.get("workload_identity_federation_role");
      if (!roleOutput) {
        const nearMiss = [...blocks.keys()].find((n) => n.startsWith("workload_identity_federation_role"));
        return {
          pass: false,
          detail: nearMiss
            ? `output is named "${nearMiss}" — the convention is "workload_identity_federation_role"`
            : 'missing output "workload_identity_federation_role"',
        };
      }
      return {
        pass: /arn:aws:iam::/.test(roleOutput) && !/aws_iam_role\.[\w-]+(\[\d+\])?\.arn/.test(roleOutput),
        detail: "ARN is read off aws_iam_role instead of being constructed — that closes a dependency cycle through the BBD UUID in the WIF subjects",
      };
    },
  },
  {
    id: "aws_wif_integration_env",
    category: "aws_backplane",
    name: "Integration wires AWS_ROLE_ARN and AWS_WEB_IDENTITY_TOKEN_FILE",
    emoji: "🌐",
    fn: (mod) => {
      if (awsBackplanePattern(mod) !== "wif") return NOT_WIF;
      const content = readIntegrationTf(mod);
      if (!content) return { pass: false, detail: "no integration file" };
      const hasRoleArn = /\bAWS_ROLE_ARN\b/.test(content);
      const hasTokenFile = /\bAWS_WEB_IDENTITY_TOKEN_FILE\b/.test(content);
      if (!hasRoleArn) return { pass: false, detail: "AWS_ROLE_ARN is not wired as an environment input" };
      if (!hasTokenFile)
        return { pass: false, detail: "AWS_WEB_IDENTITY_TOKEN_FILE is not wired — the AWS SDK has no token to exchange" };
      // The AWS audience is namespace-specific and differs per self-hosted runner, so it is read
      // from the definition's status, which follows its runner, rather than hardcoded or borrowed
      // from another integration.
      const runnerWif = "meshstack_building_block_definition\\.[\\w-]+\\.status\\.workload_identity_federation";
      return {
        pass:
          new RegExp(runnerWif + "\\.issuer").test(content) &&
          new RegExp(runnerWif + "\\.aws\\.audience").test(content),
        detail: "issuer and aws.audience do not come from meshstack_building_block_definition.<name>.status.workload_identity_federation",
      };
    },
  },
  {
    id: "aws_cross_account_provider_aliases",
    category: "aws_backplane",
    name: "Declares aws.management and aws.backplane aliases",
    emoji: "🧭",
    fn: (mod) => {
      if (awsBackplanePattern(mod) !== "cross_account") return NOT_CROSS_ACCOUNT;
      const allTf = readAllBackplaneTf(mod);
      // Read the configuration_aliases list itself: a bare `provider = aws.backplane` elsewhere in
      // the module is a use, not a declaration.
      const aliases = allTf.match(/configuration_aliases\s*=\s*\[[^\]]*\]/)?.[0];
      if (!aliases) return { pass: false, detail: "no configuration_aliases — the caller cannot point the backplane at two accounts" };
      const hasManagement = /aws\.management\b/.test(aliases);
      const hasBackplane = /aws\.backplane\b/.test(aliases);
      return {
        pass: hasManagement && hasBackplane,
        detail: hasManagement
          ? "no aws.backplane alias — the IAM user must live in a dedicated automation account"
          : "no aws.management alias — the org-wide resources must be applied against the management account",
      };
    },
  },
  {
    id: "aws_stackset_auto_deployment",
    category: "aws_backplane",
    name: "StackSet is SERVICE_MANAGED, auto-deploying, retaining nothing",
    emoji: "📚",
    fn: (mod) => {
      if (awsBackplanePattern(mod) !== "cross_account") return NOT_CROSS_ACCOUNT;
      const allTf = readAllBackplaneTf(mod);
      const blocks = extractResourceBlocks(allTf, "aws_cloudformation_stack_set");
      if (blocks.size === 0) return { pass: null, detail: "no aws_cloudformation_stack_set resources" };
      const faults = [];
      for (const [name, body] of blocks) {
        if (!/permission_model\s*=\s*"SERVICE_MANAGED"/.test(body)) faults.push(`${name}: not SERVICE_MANAGED`);
        if (!/auto_deployment\s*\{[^}]*enabled\s*=\s*true/.test(body)) faults.push(`${name}: auto_deployment not enabled`);
        if (!/retain_stacks_on_account_removal\s*=\s*false/.test(body)) faults.push(`${name}: retain_stacks_on_account_removal is not false`);
        if (!/ignore_changes\s*=\s*\[[^\]]*administration_role_arn/.test(body)) faults.push(`${name}: administration_role_arn not in ignore_changes`);
      }
      return { pass: faults.length === 0, detail: faults.join("; ") };
    },
  },
  {
    id: "aws_cross_account_outputs",
    category: "aws_backplane",
    name: "Outputs the access key, a sensitive secret, and the target role name",
    emoji: "🔑",
    fn: (mod) => {
      if (awsBackplanePattern(mod) !== "cross_account") return NOT_CROSS_ACCOUNT;
      const outputsTf = readBackplaneFile(mod, "outputs.tf");
      if (!outputsTf) return { pass: false, detail: "no outputs.tf" };
      const blocks = extractOutputBlocks(outputsTf);
      if (!blocks.has("aws_access_key_id")) return { pass: false, detail: 'missing output "aws_access_key_id"' };
      const secret = blocks.get("aws_secret_access_key");
      if (!secret) return { pass: false, detail: 'missing output "aws_secret_access_key"' };
      if (!/sensitive\s*=\s*true/.test(secret))
        return { pass: false, detail: "aws_secret_access_key is not marked sensitive = true" };
      // role_name names the role a StackSet deploys into the target accounts. A backplane that
      // reaches a single account through a role it creates itself has no such name to publish, so
      // only StackSet-based backplanes are held to it.
      const hasStackSet = extractResourceBlocks(readAllBackplaneTf(mod), "aws_cloudformation_stack_set").size > 0;
      return {
        pass: !hasStackSet || blocks.has("role_name"),
        detail: 'missing output "role_name" — the building block cannot name the role it assumes in the target account',
      };
    },
  },

  // ─── Azure Backplane ────────────────────────────────────────────────────
  {
    id: "azure_uses_uami",
    category: "azure_backplane",
    name: "Uses azurerm_user_assigned_identity",
    emoji: "🪪",
    fn: (mod) => {
      const mainTf = readBackplaneTf(mod);
      if (!mainTf) return { pass: false, detail: "no backplane main.tf" };
      return {
        pass: /resource\s+"azurerm_user_assigned_identity"/.test(mainTf),
      };
    },
  },
  {
    id: "azure_no_azuread_application",
    category: "azure_backplane",
    name: "No azuread_application resources",
    emoji: "🚫",
    fn: (mod) => {
      const allTf = readAllBackplaneTf(mod);
      if (!allTf) return { pass: true, detail: "no backplane tf files" };
      return {
        pass: !/resource\s+"azuread_application"/.test(allTf),
        detail: "azuread_application found — migrate to azurerm_user_assigned_identity",
      };
    },
  },
  {
    id: "azure_no_spn",
    category: "azure_backplane",
    name: "No azuread_service_principal resources",
    emoji: "🚫",
    fn: (mod) => {
      const allTf = readAllBackplaneTf(mod);
      if (!allTf) return { pass: true, detail: "no backplane tf files" };
      return {
        pass: !/resource\s+"azuread_service_principal"/.test(allTf),
        detail: "azuread_service_principal found — migrate to UAMI",
      };
    },
  },
  {
    id: "azure_no_app_password",
    category: "azure_backplane",
    name: "No azuread_application_password resources",
    emoji: "🔑",
    fn: (mod) => {
      const allTf = readAllBackplaneTf(mod);
      if (!allTf) return { pass: true, detail: "no backplane tf files" };
      return {
        pass: !/resource\s+"azuread_application_password"/.test(allTf),
        detail: "client secret found — UAMIs with WIF need no secrets",
      };
    },
  },
  {
    id: "azure_federated_identity_credential",
    category: "azure_backplane",
    name: "Uses azurerm_federated_identity_credential",
    emoji: "🔗",
    fn: (mod) => {
      const allTf = readAllBackplaneTf(mod);
      if (!allTf) return { pass: false, detail: "no backplane tf files" };
      return {
        pass: /resource\s+"azurerm_federated_identity_credential"/.test(allTf),
      };
    },
  },
  {
    id: "azure_wif_nonnullable",
    category: "azure_backplane",
    name: "workload_identity_federation is non-nullable",
    emoji: "⚡",
    fn: (mod) => {
      const varsTf = readBackplaneFile(mod, "variables.tf");
      if (!varsTf) return { pass: false, detail: "no variables.tf" };
      const hasWifVar = /variable\s+"workload_identity_federation"/.test(varsTf);
      if (!hasWifVar) return { pass: false, detail: "variable not found" };
      const hasNullableFalse = /nullable\s*=\s*false/.test(varsTf);
      const hasDefaultNull = /variable\s+"workload_identity_federation"[\s\S]*?default\s*=\s*null/.test(varsTf);
      return {
        pass: hasNullableFalse || !hasDefaultNull,
        detail: hasDefaultNull ? "default = null makes WIF optional" : undefined,
      };
    },
  },
  {
    id: "azure_no_create_spn_toggle",
    category: "azure_backplane",
    name: "No create_service_principal_name toggle",
    emoji: "🧹",
    fn: (mod) => {
      const varsTf = readBackplaneFile(mod, "variables.tf");
      if (!varsTf) return { pass: true, detail: "no variables.tf" };
      return {
        pass: !/variable\s+"create_service_principal_name"/.test(varsTf),
        detail: "legacy toggle pattern — remove in favour of UAMI",
      };
    },
  },
  {
    id: "azure_identity_output",
    category: "azure_backplane",
    name: 'Outputs identity (client_id, principal_id, tenant_id)',
    emoji: "📤",
    fn: (mod) => {
      const outputsTf = readBackplaneFile(mod, "outputs.tf");
      if (!outputsTf) return { pass: false, detail: "no outputs.tf" };
      return {
        pass: /output\s+"identity"/.test(outputsTf),
        detail: 'missing output "identity" block',
      };
    },
  },
  {
    id: "azure_integration_rg_location",
    category: "azure_backplane",
    name: "Integration has azure_location",
    emoji: "📍",
    fn: (mod) => {
      const content = readIntegrationTf(mod);
      if (!content) return { pass: false, detail: "no integration file" };
      const hasLocation = /variable\s+"azure_location"/.test(content);
      return {
        pass: hasLocation,
        detail: "missing azure_location",
      };
    },
  },

  // ─── GCP Backplane ──────────────────────────────────────────────────────
  {
    id: "gcp_uses_wif",
    category: "gcp_backplane",
    name: "Uses google_iam_workload_identity_pool + _provider",
    emoji: "🔐",
    fn: (mod) => {
      const allTf = readAllBackplaneTf(mod);
      if (!allTf) return { pass: false, detail: "no backplane tf files" };
      const hasPool = /resource\s+"google_iam_workload_identity_pool"/.test(allTf);
      const hasProvider = /resource\s+"google_iam_workload_identity_pool_provider"/.test(allTf);
      return {
        pass: hasPool && hasProvider,
        detail: hasPool ? "pool present without a provider" : "no workload identity pool",
      };
    },
  },
  {
    id: "gcp_no_sa_key",
    category: "gcp_backplane",
    name: "No google_service_account_key resource",
    emoji: "🚫",
    fn: (mod) => {
      const allTf = readAllBackplaneTf(mod);
      if (!allTf) return { pass: true, detail: "no backplane tf files" };
      return {
        pass: !/resource\s+"google_service_account_key"/.test(allTf),
        detail: "google_service_account_key found — migrate to workload identity federation",
      };
    },
  },
  {
    id: "gcp_wif_nonnullable",
    category: "gcp_backplane",
    name: "workload_identity_federation is non-nullable",
    emoji: "⚡",
    fn: (mod) => {
      const varsTf = readBackplaneFile(mod, "variables.tf");
      if (!varsTf) return { pass: false, detail: "no variables.tf" };
      const wifVar = extractVariableBlocks(varsTf).get("workload_identity_federation");
      if (!wifVar) return { pass: false, detail: "variable not found" };
      const hasDefaultNull = /default\s*=\s*null/.test(wifVar);
      return {
        pass: /nullable\s*=\s*false/.test(wifVar) || !hasDefaultNull,
        detail: hasDefaultNull
          ? "default = null makes WIF optional — a service account key fallback is not a supported path"
          : undefined,
      };
    },
  },
  {
    id: "gcp_workload_identity_user_binding",
    category: "gcp_backplane",
    name: "Grants roles/iam.workloadIdentityUser on the service account",
    emoji: "🪪",
    fn: (mod) => {
      const allTf = readAllBackplaneTf(mod);
      if (!allTf) return { pass: false, detail: "no backplane tf files" };
      const hasBinding = /resource\s+"google_service_account_iam_(binding|member)"/.test(allTf);
      const hasRole = /roles\/iam\.workloadIdentityUser/.test(allTf);
      return {
        pass: hasBinding && hasRole,
        detail: hasBinding
          ? "service account IAM binding does not grant roles/iam.workloadIdentityUser"
          : "no google_service_account_iam_binding for the pool",
      };
    },
  },
  {
    id: "gcp_wif_attribute_condition",
    category: "gcp_backplane",
    name: "Pool provider restricts google.subject via attribute_condition",
    emoji: "🛂",
    fn: (mod) => {
      const allTf = readAllBackplaneTf(mod);
      if (!allTf) return { pass: false, detail: "no backplane tf files" };
      const hasCondition = /attribute_condition\s*=/.test(allTf);
      if (!hasCondition)
        return { pass: false, detail: "no attribute_condition — the pool provider accepts every subject the issuer signs" };
      if (!/google\.subject/.test(allTf))
        return { pass: false, detail: "attribute_condition does not constrain google.subject" };
      if (/google\.subject\.startsWith\(/.test(allTf))
        return {
          pass: false,
          detail: "google.subject.startsWith(...) admits every definition sharing the prefix — meshStack resolves a subject per definition, so match it exactly",
        };
      return {
        pass: /google\.subject\s*==/.test(allTf) && /var\.workload_identity_federation_trust\.subjects/.test(allTf),
        detail: "attribute_condition does not compare google.subject to each var.workload_identity_federation_trust.subjects entry",
      };
    },
  },
  {
    id: "gcp_credentials_output",
    category: "gcp_backplane",
    name: "Outputs credentials_json (sensitive) and service_account_email",
    emoji: "📤",
    fn: (mod) => {
      const outputsTf = readBackplaneFile(mod, "outputs.tf");
      if (!outputsTf) return { pass: false, detail: "no outputs.tf" };
      const blocks = extractOutputBlocks(outputsTf);
      const credentials = blocks.get("credentials_json");
      const hasEmail = blocks.has("service_account_email");
      if (!credentials) return { pass: false, detail: 'missing output "credentials_json"' };
      if (!hasEmail) return { pass: false, detail: 'missing output "service_account_email"' };
      if (!/sensitive\s*=\s*true/.test(credentials))
        return { pass: false, detail: "credentials_json is not marked sensitive = true" };
      if (/google_iam_workload_identity_pool_provider\.[\w-]+\.name/.test(credentials))
        return {
          pass: false,
          detail: "the audience is read off the pool provider, whose attribute_condition names the definition that consumes this output — build it from data.google_project and the pool identifier",
        };
      return {
        pass: /\/\/iam\.googleapis\.com\/projects\//.test(credentials),
        detail: "the audience is not the //iam.googleapis.com/projects/<number>/locations/global/workloadIdentityPools/<pool>/providers/<provider> form",
      };
    },
  },
  {
    id: "gcp_iam_propagation_wait",
    category: "gcp_backplane",
    name: "credentials_json waits on a time_sleep for IAM propagation",
    emoji: "⏳",
    fn: (mod) => {
      const allTf = readAllBackplaneTf(mod);
      if (!allTf) return { pass: false, detail: "no backplane tf files" };
      if (!/resource\s+"time_sleep"/.test(allTf))
        return { pass: false, detail: "no time_sleep — credentials are published before the IAM grants take effect" };
      const outputsTf = readBackplaneFile(mod, "outputs.tf");
      const credentials = outputsTf ? extractOutputBlocks(outputsTf).get("credentials_json") : null;
      if (!credentials) return { pass: false, detail: 'missing output "credentials_json"' };
      return {
        pass: /depends_on\s*=\s*\[[^\]]*time_sleep\./.test(credentials),
        detail: "credentials_json does not depends_on the time_sleep, so consumers do not inherit the wait",
      };
    },
  },
  {
    id: "gcp_project_service_disable_on_destroy",
    category: "gcp_backplane",
    name: "google_project_service sets disable_on_destroy = false",
    emoji: "🔌",
    fn: (mod) => {
      const allTf = readAllBackplaneTf(mod);
      if (!allTf) return { pass: false, detail: "no backplane tf files" };
      const blocks = extractResourceBlocks(allTf, "google_project_service");
      if (blocks.size === 0)
        return { pass: null, detail: "no google_project_service resources" };
      const offenders = [...blocks]
        .filter(([, body]) => !/disable_on_destroy\s*=\s*false/.test(body))
        .map(([name]) => name);
      return {
        pass: offenders.length === 0,
        detail: `disable_on_destroy is not false on ${offenders.join(", ")} — a destroy would switch the API off project-wide`,
      };
    },
  },
  {
    id: "gcp_no_provider_block",
    category: "gcp_backplane",
    name: 'No provider "google" block in backplane/',
    emoji: "🧹",
    fn: (mod) => {
      const allTf = readAllBackplaneTf(mod);
      if (!allTf) return { pass: true, detail: "no backplane tf files" };
      return {
        pass: !/^provider\s+"google"/m.test(allTf),
        detail: 'provider "google" found — a module with a provider block cannot be wrapped in count/for_each/depends_on',
      };
    },
  },

  // ─── STACKIT Backplane ──────────────────────────────────────────────────
  {
    id: "stackit_uses_wif",
    category: "stackit_backplane",
    name: "Uses stackit_service_account_federated_identity_provider",
    emoji: "🔐",
    fn: (mod) => {
      const allTf = readAllBackplaneTf(mod);
      if (!allTf) return { pass: false, detail: "no backplane tf files" };
      return {
        pass: /resource\s+"stackit_service_account_federated_identity_provider"/.test(allTf),
      };
    },
  },
  {
    id: "stackit_no_sa_key",
    category: "stackit_backplane",
    name: "No stackit_service_account_key resource",
    emoji: "🚫",
    fn: (mod) => {
      const allTf = readAllBackplaneTf(mod);
      if (!allTf) return { pass: true, detail: "no backplane tf files" };
      return {
        pass: !/resource\s+"stackit_service_account_key"/.test(allTf),
        detail: "stackit_service_account_key found — migrate to WIF",
      };
    },
  },
  {
    id: "stackit_sa_email_output",
    category: "stackit_backplane",
    name: "Outputs service_account_email (not key)",
    emoji: "📤",
    fn: (mod) => {
      const outputsTf = readBackplaneFile(mod, "outputs.tf");
      if (!outputsTf) return { pass: false, detail: "no outputs.tf" };
      const hasEmailOutput = /output\s+"service_account_email"/.test(outputsTf);
      const hasKeyOutput = /output\s+"service_account_key"/.test(outputsTf);
      return {
        pass: hasEmailOutput && !hasKeyOutput,
        detail: !hasEmailOutput
          ? 'missing output "service_account_email"'
          : "service_account_key output found — replace with service_account_email",
      };
    },
  },
  {
    id: "stackit_wif_env_auth",
    category: "stackit_backplane",
    name: "WIF auth via env vars, not provider arguments",
    emoji: "⚡",
    fn: (mod) => {
      const providerTf = join(mod.path, "buildingblock", "provider.tf");
      if (!existsSync(providerTf)) return { pass: false, detail: "no provider.tf" };
      const authArg = readFileSync(providerTf, "utf-8").match(
        /\b(service_account_email|service_account_key|service_account_token|use_oidc)\s*=/
      );
      if (authArg) {
        return {
          pass: false,
          detail: `provider.tf sets ${authArg[1]} — authenticate via the STACKIT_* env var inputs instead`,
        };
      }
      const integration = readIntegrationTf(mod);
      if (!integration) return { pass: false, detail: "no integration file" };
      const missing = STACKIT_WIF_ENV_VARS.filter(
        (v) => !new RegExp(`${v}\\s*=\\s*\\{`).test(integration)
      );
      return {
        pass: missing.length === 0,
        detail: `integration is missing env var input(s): ${missing.join(", ")}`,
      };
    },
  },

  // ─── Testing ────────────────────────────────────────────────────────────
  {
    id: "backplane",
    category: "testing",
    name: "backplane/ directory (optional tier)",
    emoji: "⚙️",
    fn: (mod) => {
      // The tier is genuinely optional: building blocks that need no cloud-side setup opt out by
      // declaring `requiresBackplane: false` in their buildingblock/README.md front-matter, which
      // makes this check not applicable rather than failing. Keeping the opt-out explicit means an
      // absent backplane still shows as a gap unless someone deliberately declared otherwise.
      if (/^requiresBackplane:\s*false\s*$/m.test(readFrontmatter(mod))) {
        return { pass: null, detail: "module declares requiresBackplane: false" };
      }
      return { pass: existsSync(join(mod.path, "backplane")) };
    },
  },
  {
    id: "e2e_tests",
    category: "testing",
    name: "e2e/ test directory exists",
    emoji: "🧪",
    fn: (mod) => e2eCoveredBy(mod) ?? { pass: existsSync(join(mod.path, "e2e")) },
  },
  {
    id: "no_buildingblock_tftest",
    category: "testing",
    name: "no .tftest.hcl outside e2e/",
    emoji: "🚫",
    targets: ["module", "refArch"],
    fn: (mod) => {
      const e2e = join(mod.path, "e2e");
      const stray = collectFilesRecursive(mod.path)
        .filter((file) => file.endsWith(".tftest.hcl") && !file.startsWith(e2e + "/"))
        .map((file) => relative(mod.path, file));
      return stray.length
        ? { pass: false, detail: `${stray.join(", ")} never runs; only e2e/ does` }
        : { pass: true };
    },
  },
  {
    id: "no_mocked_tftest",
    category: "testing",
    name: "every .tftest.hcl runs against real infrastructure",
    emoji: "🎭",
    targets: ["module", "refArch"],
    fn: (mod) => {
      const tests = collectFilesRecursive(mod.path).filter((file) => file.endsWith(".tftest.hcl"));
      if (tests.length === 0) return { pass: null, detail: "no .tftest.hcl files" };

      const offenders = [];
      for (const file of tests) {
        const where = relative(mod.path, file);
        if (/(^|[_.-])unit([_.-]|$)/.test(basename(file, ".tftest.hcl"))) {
          offenders.push(`${where} is named as a unit test`);
        }
        const content = readFileSync(file, "utf-8");
        const blocks = content.matchAll(/^\s*(mock_provider|override_resource|override_data|override_module)\b/gm);
        for (const block of new Set([...blocks].map((m) => m[1]))) offenders.push(`${where} uses ${block}`);
      }

      return offenders.length
        ? { pass: false, detail: `delete what mocks or overrides, and assert on the live apply instead: ${offenders.join("; ")}` }
        : { pass: true };
    },
  },
  {
    id: "e2e_tftest",
    category: "testing",
    name: "e2e/ contains .tftest.hcl files",
    emoji: "✅",
    fn: (mod) => {
      const covered = e2eCoveredBy(mod);
      if (covered) return covered;
      const e2eDir = join(mod.path, "e2e", "tests");
      if (!existsSync(e2eDir)) return { pass: false };
      const files = readdirSync(e2eDir);
      return { pass: files.some((f) => f.endsWith(".tftest.hcl")) };
    },
  },
  {
    id: "ref_arch_e2e",
    category: "testing",
    name: "e2e/main.tf with a .tftest.hcl",
    emoji: "🧪",
    targets: ["refArch"],
    needsCode: "no buildingblock code and no e2e yet",
    fn: (ra) => {
      const e2e = join(ra.path, "e2e");
      if (!existsSync(join(e2e, "main.tf"))) {
        return { pass: false, detail: "no e2e/main.tf, which is what the smoke tests discover" };
      }
      const tests = collectFilesRecursive(e2e).filter((file) => file.endsWith(".tftest.hcl"));
      return tests.length ? { pass: true } : { pass: false, detail: "e2e/ has no .tftest.hcl" };
    },
  },

  // ─── Shared Practices ───────────────────────────────────────────────────
  {
    id: "no_sensitive_outputs",
    category: "shared",
    name: "no building block output carries a secret",
    emoji: "🔐",
    targets: ["module", "refArch"],
    needsCode: true,
    fn: (target) => {
      const offenders = [];
      let declared = 0;
      for (const { file, content } of readCodeFiles(target)) {
        const where = relative(target.path, file);
        if (basename(dirname(file)) === "buildingblock") {
          for (const [name, body] of extractOutputBlocks(content)) {
            declared++;
            if (/^\s*sensitive\s*=\s*true\b/m.test(body)) offenders.push(`${where}: output "${name}"`);
          }
        }
        for (const [bbd, body] of extractResourceBlocks(content, "meshstack_building_block_definition")) {
          for (const [key, entry] of bbdEntries(body, "outputs")) {
            declared++;
            if (/^\s*(is_)?sensitive\s*=\s*true\b/m.test(entry)) offenders.push(`${where}: ${bbd} output "${key}"`);
          }
        }
      }
      if (declared === 0) return { pass: null, detail: "declares no building block outputs" };
      return listOffenders(offenders, "write the credential to a secret store of the platform and output where it is");
    },
  },
  {
    id: "sensitive_inputs_ephemeral",
    category: "shared",
    name: "Sensitive building block variables are ephemeral",
    emoji: "🫥",
    targets: ["module", "refArch"],
    needsCode: true,
    fn: (target) => {
      const byDir = Map.groupBy(
        readCodeFiles(target).filter(({ file }) => basename(dirname(file)) === "buildingblock"),
        ({ file }) => dirname(file)
      );
      const offenders = [];
      let sensitive = 0;
      for (const [dir, files] of byDir) {
        for (const { file, content } of files) {
          for (const [name, body] of extractVariableBlocks(content)) {
            if (!/^\s*sensitive\s*=\s*true\b/m.test(body)) continue;
            sensitive++;
            if (/^\s*ephemeral\s*=\s*true\b/m.test(body)) continue;
            const verdict = ephemeralOnlyUses(files, name) ? "only in providers or *_wo, can be ephemeral" : "needs a rework first";
            offenders.push(`${relative(target.path, file)}: variable "${name}" (${verdict})`);
          }
        }
      }
      if (sensitive === 0) return { pass: null, detail: "no sensitive building block variables" };
      return listOffenders(offenders, "the runner uploads the plan file to meshStack, which keeps a sensitive value in plain text, so set ephemeral = true");
    },
  },
  {
    id: "bbd_structured_inputs",
    category: "shared",
    name: "User-facing BBD inputs backed by an object or map variable are JSON with a json_schema",
    emoji: "🧾",
    targets: ["module", "refArch"],
    needsCode: true,
    fn: (target) => {
      const offenders = [];
      let checked = 0;
      for (const { where, bbd, key, entry, variable } of bbdInputsWithVariables(target)) {
        if (inputAttribute(entry, "type") !== "CODE") continue;
        // Only these two are filled in through meshPanel, so only they get a form.
        if (!/^(USER_INPUT|PLATFORM_OPERATOR_MANUAL_INPUT)$/.test(inputAttribute(entry, "assignment_type"))) continue;
        checked++;
        const tfType = variable.match(/^\s*type\s*=\s*(\w+)/m)?.[1];
        if (tfType === "object" || tfType === "map") offenders.push(`${where}: ${bbd} input "${key}" (${tfType})`);
      }
      if (checked === 0) return { pass: null, detail: "no user-facing CODE inputs backed by a variable" };
      return listOffenders(offenders, "a form beats free-form HCL for structured values, make these JSON inputs with a json_schema");
    },
  },
  {
    id: "bbd_input_order",
    category: "shared",
    name: "BBD inputs and their variables are declared in display order",
    emoji: "🔢",
    targets: ["module", "refArch"],
    needsCode: true,
    fn: (target) => {
      const offenders = [];
      let checked = 0;
      for (const { where, bbd, inputs, variables } of bbdsWithImplementation(target)) {
        const orders = new Map(inputs.map(([key, entry]) => [key, displayOrder(entry)]).filter(([, n]) => !Number.isNaN(n)));
        if (orders.size === 0) continue;
        checked++;
        if (!isAscending([...orders.values()])) offenders.push(`${where}: ${bbd} inputs`);
        const tail = inputs
          .filter(([key]) => orders.has(key))
          .toSorted(([a], [b]) => orders.get(a) - orders.get(b))
          .map(([key, entry]) => (key === "hub" ? 2 : /^(USER_INPUT|PAYMENT_METHOD|PLATFORM_OPERATOR_MANUAL_INPUT|STATIC)$/.test(inputAttribute(entry, "assignment_type")) ? 0 : 1));
        if (!isAscending(tail)) offenders.push(`${where}: ${bbd} generated inputs and hub are not last`);
        if (!isAscending([...variables.keys()].filter((key) => orders.has(key)).map((key) => orders.get(key)))) {
          offenders.push(`${where}: ${bbd} buildingblock variables`);
        }
      }
      if (checked === 0) return { pass: null, detail: "no definition inputs with a display_order" };
      return listOffenders(offenders, "declare the inputs by ascending display_order, generated inputs and then hub last, and the variables they feed in the same order");
    },
  },
  {
    id: "bbd_input_defaults",
    category: "shared",
    name: "The definition owns input defaults: variables fed by required inputs have no default and are not nullable, no \"\" as unset",
    emoji: "🪞",
    targets: ["module", "refArch"],
    needsCode: true,
    fn: (target) => {
      const offenders = [];
      let checked = 0;
      for (const { where, bbd, key, entry, variable } of bbdInputsWithVariables(target)) {
        checked++;
        if (/^\s*(is_optional\s*=\s*true\b|condition\s*=)/m.test(entry)) continue;
        if (/^\s*const\s*=\s*true\b/m.test(variable)) continue;
        if (/^\s*default\s*=/m.test(variable)) offenders.push(`${where}: ${bbd} input "${key}" (required, but the variable has a default)`);
        if (!/^\s*nullable\s*=\s*false\b/m.test(variable)) offenders.push(`${where}: ${bbd} input "${key}" (required, but the variable is nullable)`);
      }
      for (const { where, bbd, inputs, code } of bbdsWithImplementation(target)) {
        for (const [key] of inputs) {
          const emptyString = new RegExp(String.raw`coalesce\(\s*var\.${key}\s*,\s*""|var\.${key}\s*[!=]=\s*""|compact\(\s*\[\s*var\.${key}\b`);
          if (emptyString.test(code)) offenders.push(`${where}: ${bbd} input "${key}" (handles "" as unset)`);
        }
      }
      if (checked === 0) return { pass: null, detail: "no definition inputs backed by a variable" };
      return listOffenders(offenders, "put a sane default into default_value and give the variable of a required input no default and nullable = false, or make the input optional and check only for null");
    },
  },

  // ─── Reference Architecture ─────────────────────────────────────────────
  {
    id: "ref_arch_children_version_latest",
    category: "ref_arch",
    name: "Children are ordered with, and outputs hand out, version_latest",
    emoji: "🆕",
    targets: ["refArch"],
    needsCode: true,
    fn: (ra) => {
      const files = readCodeFiles(ra);
      const moduleDirs = new Map(files.flatMap(({ file, content }) => moduleSourceDirs(file, content)));
      const offenders = [];
      let checked = 0;
      for (const { file, content } of files) {
        const where = relative(ra.path, file);
        for (const [name, body] of extractResourceBlocks(content, "meshstack_building_block")) {
          const expression = attributeExpression(body, "building_block_definition_version_ref");
          if (expression === null) continue;
          checked++;
          const viaModule = expression.match(/^module\.(\w+)\.building_block_definition\.version_ref$/)?.[1];
          if (expression.startsWith("{")) {
            offenders.push(`${where}: ${name} builds its version ref by hand`);
          } else if (expression.includes("version_latest_release")) {
            offenders.push(`${where}: ${name} orders version_latest_release`);
          } else if (viaModule && handsOutRelease(moduleDirs.get(viaModule))) {
            offenders.push(`${where}: ${name} orders module.${viaModule}'s version_latest_release`);
          }
        }
        for (const [name, body] of extractOutputBlocks(content)) {
          checked++;
          if (body.includes("version_latest_release")) offenders.push(`${where}: output "${name}" hands out version_latest_release`);
        }
      }
      if (checked === 0) return { pass: null, detail: "orders no building blocks and hands out no outputs" };
      return listOffenders(offenders, "order and hand out version_latest, so a new version may move to another runner");
    },
  },
  {
    id: "ref_arch_hub_ref_from_caller",
    category: "ref_arch",
    name: "Hub sources, ref_name and assets follow var.hub.git_ref",
    emoji: "📌",
    targets: ["refArch"],
    needsCode: true,
    fn: (ra) => {
      const offenders = [];
      let checked = 0;
      for (const { file, content } of readCodeFiles(ra)) {
        const where = relative(ra.path, file);
        const pinned = [
          ...[...content.matchAll(/meshstack-hub\/\/[^"]*/g)].map((m) => [m[0], m[0].match(/\?ref=(.*)$/)?.[1]]),
          ...[...content.matchAll(/raw\.githubusercontent\.com\/meshcloud\/meshstack-hub\/(\$\{[^}]*\}|[^/"]*)/g)].map((m) => [m[0], m[1]]),
          ...[...content.matchAll(/^\s*ref_name\s*=\s*(.+?)\s*$/gm)].map((m) => [m[0].trim(), m[1].replace(/^"\$\{(.*)\}"$/, "$1")]),
        ];
        for (const [text, ref] of pinned) {
          checked++;
          if (!/^(\$\{)?var\.hub\.git_ref\}?$/.test(ref ?? "")) offenders.push(`${where}: ${text}`);
        }
      }
      if (checked === 0) return { pass: null, detail: "references no Hub source" };
      return listOffenders(offenders, "take the Hub ref from the caller's var.hub.git_ref");
    },
  },
  {
    id: "ref_arch_approval_policies",
    category: "ref_arch",
    name: "The definition takes its approval policies from a variable",
    emoji: "🛂",
    targets: ["refArch"],
    needsCode: true,
    fn: (ra) => {
      const content = readIntegrationTf(ra);
      if (!content) return { pass: false, detail: "no meshstack_integration.tf, so nothing registers the architecture" };
      return /^\s*approval_policies\s*=\s*var\.\w+/m.test(content)
        ? { pass: true }
        : { pass: false, detail: "set spec.approval_policies from an approval_policies variable" };
    },
  },
  {
    id: "ref_arch_diagram",
    category: "ref_arch",
    name: "README.md shows a committed diagram (.dot + .svg)",
    emoji: "🗺️",
    targets: ["refArch"],
    fn: (ra) => {
      const readme = readFileSync(join(ra.path, "README.md"), "utf-8");
      const shown = [...readme.matchAll(/!\[[^\]]*\]\(([^)\s]+)\.svg\)/g)].map((m) => m[1]);
      if (shown.length === 0) return { pass: false, detail: "README.md shows no .svg diagram" };
      const missing = shown.filter((name) => !existsSync(join(ra.path, `${name}.svg`)) || !existsSync(join(ra.path, `${name}.dot`)));
      return missing.length
        ? { pass: false, detail: `missing .dot or .svg for ${missing.join(", ")}` }
        : { pass: true };
    },
  },
];

const detectorsFor = (kind) => detectors.filter((d) => (d.targets ?? ["module"]).includes(kind));

const categoriesFor = (kind) =>
  Object.fromEntries(
    Object.entries(CATEGORIES).filter(([catId]) => detectorsFor(kind).some((d) => d.category === catId))
  );

// ─── Helpers ────────────────────────────────────────────────────────────────

function readFrontmatter(mod) {
  const readmePath = join(mod.path, "buildingblock", "README.md");
  if (!existsSync(readmePath)) return "";
  return readFileSync(readmePath, "utf-8").split(/^---\s*$/m)[1] ?? "";
}

function e2eCoveredBy(mod) {
  const target = readFrontmatter(mod).match(/^e2eCoveredBy:\s*(\S+)\s*$/m)?.[1];
  if (!target) return null;
  if (!existsSync(join(MODULES_DIR, target, "e2e", "tests"))) {
    return { pass: false, detail: `e2eCoveredBy: modules/${target}/e2e/tests does not exist` };
  }
  return { pass: null, detail: `covered by modules/${target}/e2e` };
}

function readIntegrationTf(mod) {
  const p = join(mod.path, "meshstack_integration.tf");
  if (!existsSync(p)) return null;
  return readFileSync(p, "utf-8");
}

// A manual or pipeline implementation runs no tofu of its own: its automation lives in meshStack or
// in the customer's CI system, so buildingblock/ carries documentation only and the fields a
// terraform implementation has do not exist. Checks that only make sense for terraform then report
// "not applicable" rather than failing.
function runsTerraform(mod) {
  const content = readIntegrationTf(mod);
  if (!content) return true;
  return /^\s*terraform\s*=\s*\{/m.test(content);
}

function readBackplaneTf(mod) {
  const p = join(mod.path, "backplane", "main.tf");
  if (!existsSync(p)) return null;
  return readFileSync(p, "utf-8");
}

function readBackplaneFile(mod, filename) {
  const p = join(mod.path, "backplane", filename);
  if (!existsSync(p)) return null;
  return readFileSync(p, "utf-8");
}

function extractBBDResourceBlocks(content) {
  return content.match(/^resource\s+"meshstack_building_block_definition"\s+"[^"]+"\s*\{[\s\S]*?^}/gm) || [];
}

function extractVariableBlocks(content) {
  return extractNamedBlocks(content, "variable");
}

function extractOutputBlocks(content) {
  return extractNamedBlocks(content, "output");
}

// name → body for every `resource "<type>" "<name>"` block of the given type.
function extractResourceBlocks(content, type) {
  return extractNamedBlocks(content, `resource\\s+"${type}"`);
}

// Brace-matched so a nested `object({...})` or a one-line block cannot swallow the block that
// follows it — which a lazy `[\s\S]*?^}` regex does.
function extractNamedBlocks(content, kind) {
  const blocks = new Map();
  const re = new RegExp(`^${kind}\\s+"([^"]+)"\\s*\\{`, "gm");
  for (const m of content.matchAll(re)) {
    const open = content.indexOf("{", m.index);
    const close = findMatchingBrace(content, open);
    if (close > open) blocks.set(m[1], content.slice(m.index, close + 1));
  }
  return blocks;
}

function findMatchingBrace(text, openingBraceIndex) {
  if (openingBraceIndex < 0 || text[openingBraceIndex] !== "{") return -1;

  let depth = 0;
  let inString = false;
  let escaped = false;
  let inLineComment = false;
  let inBlockComment = false;

  for (let i = openingBraceIndex; i < text.length; i++) {
    const ch = text[i];
    const next = text[i + 1];

    if (inLineComment) {
      if (ch === "\n") inLineComment = false;
      continue;
    }

    if (inBlockComment) {
      if (ch === "*" && next === "/") {
        inBlockComment = false;
        i++;
      }
      continue;
    }

    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (ch === "\\") {
        escaped = true;
      } else if (ch === "\"") {
        inString = false;
      }
      continue;
    }

    if (ch === "#") {
      inLineComment = true;
      continue;
    }
    if (ch === "/" && next === "/") {
      inLineComment = true;
      i++;
      continue;
    }
    if (ch === "/" && next === "*") {
      inBlockComment = true;
      i++;
      continue;
    }
    if (ch === "\"") {
      inString = true;
      continue;
    }

    if (ch === "{") {
      depth++;
      continue;
    }

    if (ch === "}") {
      depth--;
      if (depth === 0) return i;
      if (depth < 0) return -1;
    }
  }

  return -1;
}

function findExpressionEnd(text, startIndex) {
  let inString = false;
  let escaped = false;
  let inLineComment = false;
  let inBlockComment = false;
  let parenDepth = 0;
  let bracketDepth = 0;
  let braceDepth = 0;

  for (let i = startIndex; i < text.length; i++) {
    const ch = text[i];
    const next = text[i + 1];

    if (inLineComment) {
      if (ch === "\n") {
        inLineComment = false;
        if (parenDepth === 0 && bracketDepth === 0 && braceDepth === 0) return i;
      }
      continue;
    }

    if (inBlockComment) {
      if (ch === "*" && next === "/") {
        inBlockComment = false;
        i++;
      }
      continue;
    }

    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (ch === "\\") {
        escaped = true;
      } else if (ch === "\"") {
        inString = false;
      }
      continue;
    }

    if (ch === "#") {
      inLineComment = true;
      continue;
    }
    if (ch === "/" && next === "/") {
      inLineComment = true;
      i++;
      continue;
    }
    if (ch === "/" && next === "*") {
      inBlockComment = true;
      i++;
      continue;
    }
    if (ch === "\"") {
      inString = true;
      continue;
    }

    if (ch === "(") parenDepth++;
    if (ch === ")") parenDepth = Math.max(0, parenDepth - 1);
    if (ch === "[") bracketDepth++;
    if (ch === "]") bracketDepth = Math.max(0, bracketDepth - 1);
    if (ch === "{") braceDepth++;
    if (ch === "}") braceDepth = Math.max(0, braceDepth - 1);

    if (ch === "\n" && parenDepth === 0 && bracketDepth === 0 && braceDepth === 0) {
      return i;
    }
  }

  return text.length;
}

export function explicitDefaultViolations(content) {
  const variableBlocks = extractVariableBlocks(content);
  const violations = new Set();

  for (const ref of collectBBDInputArgumentVariableReferences(content)) {
    const [varName, attribute] = ref.split(".");
    const variableBlock = variableBlocks.get(varName);
    if (!variableBlock) continue;

    const readType = (attribute && objectAttributeType(variableBlock, attribute)) ?? variableBlock;
    if (!/optional\s*\(/.test(readType)) continue;

    const hasDefault = /^\s*default\s*=/m.test(variableBlock);
    const hasBareObjectDefault = /default\s*=\s*\{\s*\}/s.test(variableBlock);

    if (!hasDefault || hasBareObjectDefault) {
      const reason = !hasDefault ? "missing default" : "bare default = {}";
      violations.add(`${varName} (${reason})`);
    }
  }

  return [...violations];
}

function objectAttributeType(variableBlock, attribute) {
  const objectMatch = /\btype\s*=\s*object\s*\(\s*\{/.exec(variableBlock);
  if (!objectMatch) return null;

  const open = objectMatch.index + objectMatch[0].length - 1;
  const close = findMatchingBrace(variableBlock, open);
  if (close === -1) return null;

  const body = variableBlock.slice(open + 1, close);
  for (const m of body.matchAll(new RegExp(String.raw`\b${attribute}\s*=`, "g"))) {
    const prefix = body.slice(0, m.index);
    const depth = (prefix.match(/[({[]/g) ?? []).length - (prefix.match(/[)}\]]/g) ?? []).length;
    if (depth !== 0) continue;
    const start = m.index + m[0].length;
    return body.slice(start, findExpressionEnd(body, start));
  }
  return null;
}

function collectBBDInputArgumentVariableReferences(content) {
  const refs = new Set();
  const resources = extractBBDResourceBlocks(content);

  for (const resourceBlock of resources) {
    const inputsRe = /inputs\s*=\s*\{/g;
    for (const m of resourceBlock.matchAll(inputsRe)) {
      const openingBraceIndex = m.index + m[0].lastIndexOf("{");
      const closingBraceIndex = findMatchingBrace(resourceBlock, openingBraceIndex);
      if (closingBraceIndex === -1) continue;

      const inputsBody = resourceBlock.slice(openingBraceIndex + 1, closingBraceIndex);
      const argumentRe = /\bargument\s*=\s*/g;

      for (const argumentMatch of inputsBody.matchAll(argumentRe)) {
        let exprStart = argumentMatch.index + argumentMatch[0].length;
        while (exprStart < inputsBody.length && /\s/.test(inputsBody[exprStart])) exprStart++;
        if (exprStart >= inputsBody.length) continue;

        let exprEnd;
        if (inputsBody[exprStart] === "{") {
          const blockEnd = findMatchingBrace(inputsBody, exprStart);
          if (blockEnd === -1) continue;
          exprEnd = blockEnd + 1;
        } else {
          exprEnd = findExpressionEnd(inputsBody, exprStart);
        }

        const expression = inputsBody.slice(exprStart, exprEnd);
        for (const varMatch of expression.matchAll(/\bvar\.([A-Za-z_]\w*)(?:\.([A-Za-z_]\w*))?/g)) {
          refs.add(varMatch[2] ? `${varMatch[1]}.${varMatch[2]}` : varMatch[1]);
        }
      }
    }
  }

  return refs;
}

// The body of the resource's `postcondition` block asserting a SUCCEEDED run, or null.
//
// A starterkit ordering a child building block is the only thing left that can fail on a failed
// child run: from meshstack provider v0.25.2 a failed run on create is a warning, so the parent
// apply otherwise reports success while the tenant has none of what it ordered. The provider
// cannot supply the check itself — the plugin protocol has no way to declare a lifecycle
// condition, and any error it returned from Create would taint the block and have the next apply
// destroy and recreate it, which is the bug the warning fixed.
function findRunStatusPostcondition(resourceBody) {
  for (const m of resourceBody.matchAll(/\bpostcondition\s*\{/g)) {
    const open = resourceBody.indexOf("{", m.index);
    const close = findMatchingBrace(resourceBody, open);
    if (close < 0) continue;
    const body = resourceBody.slice(open + 1, close);
    if (/self\.status\.succeeded\b/.test(body)) return body;
  }
  return null;
}

// The expression a BBD's `spec` assigns to one attribute, or null. `tofu fmt` indents the
// resource's own attributes by two spaces and `spec`'s by four, which is what tells a spec
// attribute apart from an identically named field of an input or output further down the resource.
function specAttributeExpression(resourceBlock, attribute) {
  const m = new RegExp(`^ {4}${attribute}[ \\t]*=[ \\t]*`, "m").exec(resourceBlock);
  return m === null ? null : resourceBlock.slice(m.index + m[0].length);
}

// The variable a catalog property reads from — `coalesce(var.x, <the module's own text>)` or a
// bare `var.x` — or null when the property is a literal no consumer can override.
function specOverrideVariable(resourceBlock, attribute) {
  const expression = specAttributeExpression(resourceBlock, attribute);
  if (expression === null) return null;
  const m = /^(?:coalesce\s*\(\s*)?var\.([A-Za-z0-9_]+)/.exec(expression);
  return m === null ? null : m[1];
}

// The BBD readme, dedented, or null when it does not resolve to a heredoc in this file. The
// readme is either the heredoc itself or, since catalog properties became overridable, a
// `coalesce(var.bbd_readme, <fallback>)` whose fallback is the heredoc or a `local` holding it.
function extractBBDReadmeContent(content) {
  const resourceBlock = extractBBDResourceBlocks(content)[0];
  if (resourceBlock === undefined) return null;

  let expression = specAttributeExpression(resourceBlock, "readme");
  if (expression === null) return null;

  const override = /^coalesce\s*\(\s*var\.[A-Za-z0-9_]+\s*,\s*/.exec(expression);
  if (override !== null) expression = expression.slice(override[0].length);

  const localReference = /^local\.([A-Za-z0-9_]+)/.exec(expression);
  if (localReference !== null) {
    const assignment = new RegExp(`(?<![A-Za-z0-9_])${localReference[1]}[ \\t]*=[ \\t]*`).exec(content);
    if (assignment === null) return null;
    expression = content.slice(assignment.index + assignment[0].length);
  }

  // Match: [chomp(] <<[-]MARKER\n...content...\nMARKER
  const m = expression.match(/^(?:chomp\s*\(\s*)?<<-?([A-Za-z_]+)\s*\n([\s\S]*?)\n[ \t]*\1\b/);
  if (!m) return null;
  const lines = m[2].split("\n");
  const nonEmpty = lines.filter((l) => l.trim().length > 0);
  if (nonEmpty.length === 0) return "";
  const minIndent = Math.min(...nonEmpty.map((l) => (l.match(/^(\s*)/) || ["", ""])[1].length));
  return lines.map((l) => l.slice(minIndent)).join("\n").trim();
}

// Every .tf file under dir, recursively — nested submodules (e.g.
// buildingblock/pre_role_assignment/) declare their own required_providers and are
// initialised as part of the parent, so their constraints count too.
function collectTfFilesRecursive(dir) {
  return collectFilesRecursive(dir).filter((file) => file.endsWith(".tf"));
}

function collectFilesRecursive(dir) {
  if (!existsSync(dir)) return [];
  const found = [];
  for (const entry of readdirSync(dir)) {
    if (entry.startsWith(".")) continue; // .terraform, .terraform.lock.hcl
    const p = join(dir, entry);
    if (statSync(p).isDirectory()) found.push(...collectFilesRecursive(p));
    else found.push(p);
  }
  return found;
}

// Heredoc bodies are documentation and example Terraform emitted for consumers (several Azure
// backplanes output a ready-to-paste provider.tf), not configuration this module is initialised
// with. Blanked rather than removed so reported line numbers still match the file.
function blankHeredocBodies(content) {
  return content.replace(
    /<<-?\s*([A-Za-z_]\w*)\r?\n[\s\S]*?^\s*\1\s*$/gm,
    (heredoc) => heredoc.split("\n").map((line, i) => (i === 0 ? line : "")).join("\n")
  );
}

// [address, body] for every `resource "meshstack_*" "<name>"` block, so a finding names the
// resource the reader has to open. Role and user/group bindings are left out:
// their `*_ref` attributes name the target by identifier alone, with no `kind`, so a `ref` output
// does not fit them.
function extractMeshstackResourceBlocks(content) {
  const blocks = [];
  for (const m of content.matchAll(/^resource\s+"(meshstack_[a-z_0-9]+)"\s+"([^"]+)"\s*\{/gm)) {
    if (/_(user|group)_binding$/.test(m[1])) continue;
    const open = content.indexOf("{", m.index);
    const close = findMatchingBrace(content, open);
    if (close > open) blocks.push([`${m[1]}.${m[2]}`, content.slice(m.index, close + 1)]);
  }
  return blocks;
}

// attribute name → expression for every `<something>_ref` / `<something>_refs` attribute.
function extractRefAttributes(body) {
  const attributes = [];
  for (const m of body.matchAll(/^[ \t]*([a-z_0-9]*_refs?)\s*=[ \t]*/gm)) {
    const start = m.index + m[0].length;
    attributes.push([m[1], body.slice(start, findExpressionEnd(body, start))]);
  }
  return attributes;
}

// The traversals inside a *_ref expression that rebuild by hand what a `ref` output carries.
// `each.value` counts too when the resource iterates over such a resource.
function handRolledRefs(expression, iteratedType) {
  const traversals = [
    ...expression.matchAll(/\b(meshstack_[a-z_0-9]+)\.[A-Za-z_]\w*(?:\[[^\]]*\])?((?:\.[A-Za-z_]\w*)*)/g),
  ].map((m) => ({ type: m[1], path: m[2], text: m[0] }));

  if (iteratedType) {
    traversals.push(
      ...[...expression.matchAll(/\beach\.value((?:\.[A-Za-z_]\w*)*)/g)].map((m) => ({
        type: iteratedType,
        path: m[1],
        text: m[0],
      }))
    );
  }

  return traversals
    .filter((t) => MESHSTACK_REF_RESOURCES.has(t.type) && !isRefShaped(t))
    .map((t) => t.text);
}

// Nobody types a uuid, so a ref holding one arrives whole. A name ref may be built from a variable
// or a literal, because a building block input from meshStack is a plain string.
function uuidRefLiterals(expression) {
  const literals = [];
  for (let open = expression.indexOf("{"); open >= 0; open = expression.indexOf("{", open + 1)) {
    const close = findMatchingBrace(expression, open);
    if (close < 0) continue;
    const literal = expression.slice(open, close + 1);
    const topLevel = literal.slice(1, -1).replace(/\{[^{}]*\}|\[[^[\]]*\]/g, "");
    const keys = new Set([...topLevel.matchAll(/(?:^|[\s,])([a-z_]+)\s*=/g)].map((m) => m[1]));
    const compact = literal.replace(/\s+/g, " ");
    if (keys.has("uuid")) literals.push(compact);
  }
  return literals;
}

const isRefShaped = ({ type, path }) =>
  path === ".ref" ||
  (type === "meshstack_building_block_definition" && BBD_VERSION_REF_OUTPUTS.has(path.slice(1)));

const isCommentLine = (line) => /^\s*(#|\/\/)/.test(line);

// A comment anywhere in the paragraph above counts, so one comment can cover a run of related
// attributes and a try() nested deep in a multi-line expression is still covered by the comment
// above the attribute that owns it. A blank line ends the paragraph.
function hasCommentAbove(lines, index) {
  for (let i = index - 1; i >= 0 && lines[i].trim() !== ""; i--) {
    if (isCommentLine(lines[i])) return true;
  }
  return false;
}

// Every `version` attribute inside a `required_providers` block across BOTH tiers.
//
// Both tiers matter because they are consumed together: a hub e2e test module loads the
// backplane and the buildingblock into one configuration, so their constraints have to
// intersect on a version that exists. A `~>` or exact pin in either tier caps the whole
// configuration — that is how modules/meshstack/noop pinned the e2e suite to meshstack
// v0.21.0 from its backplane while its buildingblock declared only `>=`.
//
// A bare `>=` is not enough either: it takes the next major on its own, which is how azurerm 5.0
// reached buildingblock code written for 4.x. Every constraint carries both bounds.
//
// Constraints are read from any .tf file, not just versions.tf: `provider.tf` is part of the
// documented module layout and legitimately carries required_providers.
function collectProviderConstraints(mod) {
  const constraints = [];

  for (const tier of ["backplane", "buildingblock"]) {
    for (const file of collectTfFilesRecursive(join(mod.path, tier))) {
      const content = blankHeredocBodies(readFileSync(file, "utf-8"));

      for (const m of content.matchAll(/required_providers\s*\{/g)) {
        const open = m.index + m[0].length - 1;
        const close = findMatchingBrace(content, open);
        if (close < 0) continue;
        const body = content.slice(open + 1, close);

        // Provider entries hold no nested braces, so a flat `name = { ... }` match is enough.
        for (const entry of body.matchAll(/([\w-]+)\s*=\s*\{([^{}]*)\}/g)) {
          const version = entry[2].match(/version\s*=\s*"([^"]+)"/);
          if (!version) continue;
          const source = entry[2].match(/source\s*=\s*"([^"]+)"/);
          constraints.push({
            file: relative(mod.path, file),
            provider: entry[1],
            source: source?.[1] ?? entry[1],
            constraint: version[1],
          });
        }
      }
    }
  }

  return constraints;
}

function readAllBuildingBlockTf(mod) {
  const dir = join(mod.path, "buildingblock");
  if (!existsSync(dir)) return null;
  const files = readdirSync(dir).filter((f) => f.endsWith(".tf"));
  if (files.length === 0) return null;
  return files.map((f) => readFileSync(join(dir, f), "utf-8")).join("\n");
}

function readAllBackplaneTf(mod) {
  const backplaneDir = join(mod.path, "backplane");
  if (!existsSync(backplaneDir)) return null;
  const files = readdirSync(backplaneDir).filter((f) => f.endsWith(".tf"));
  if (files.length === 0) return null;
  return files.map((f) => readFileSync(join(backplaneDir, f), "utf-8")).join("\n");
}

function discoverModules() {
  const modules = [];
  const providers = readdirSync(MODULES_DIR).filter((d) =>
    statSync(join(MODULES_DIR, d)).isDirectory()
  );

  for (const provider of providers) {
    const providerDir = join(MODULES_DIR, provider);
    const services = readdirSync(providerDir).filter(
      (d) =>
        statSync(join(providerDir, d)).isDirectory() &&
        !d.startsWith(".")
    );

    for (const service of services) {
      const modulePath = join(providerDir, service);
      const hasBB = existsSync(join(modulePath, "buildingblock"));
      const hasIntegration = existsSync(
        join(modulePath, "meshstack_integration.tf")
      );
      if (hasBB || hasIntegration) {
        modules.push({
          kind: "module",
          provider,
          service,
          path: modulePath,
          id: `${provider}/${service}`,
          dir: `modules/${provider}/${service}`,
          cliArg: `--module=${provider}/${service}`,
        });
      }
    }
  }

  return modules.sort((a, b) => a.id.localeCompare(b.id));
}

// The configuration a target deploys, heredoc bodies blanked. e2e/ is left out: it is a caller.
function readCodeFiles(target) {
  const e2e = join(target.path, "e2e") + "/";
  return collectTfFilesRecursive(target.path)
    .filter((file) => !file.startsWith(e2e))
    .map((file) => ({ file, content: blankHeredocBodies(readFileSync(file, "utf-8")) }));
}

// True when every `var.<name>` sits in a provider or ephemeral block or feeds a write-only
// argument, the places OpenTofu accepts an ephemeral value without more changes.
function ephemeralOnlyUses(files, name) {
  const reference = new RegExp(String.raw`\bvar\.${name}\b`);
  return files.every(({ content }) => {
    let rest = content;
    for (const m of content.matchAll(/^(provider|ephemeral)\s+"[^"]+"(\s+"[^"]+")?\s*\{/gm)) {
      const open = content.indexOf("{", m.index);
      const close = findMatchingBrace(content, open);
      if (close > open) rest = rest.slice(0, open) + " ".repeat(close - open) + rest.slice(close);
    }
    return rest.split("\n").every((line) => !reference.test(line) || /^\s*\w+_wo\s*=/.test(line));
  });
}

function listOffenders(offenders, advice) {
  if (offenders.length === 0) return { pass: true };
  const shown = offenders.slice(0, 5).join("; ");
  const more = offenders.length > 5 ? `, +${offenders.length - 5} more` : "";
  return { pass: false, detail: `${advice}: ${shown}${more}` };
}

function attributeExpression(body, attribute) {
  const m = body.match(new RegExp(String.raw`^[ \t]*${attribute}\s*=[ \t]*`, "m"));
  if (!m) return null;
  const start = m.index + m[0].length;
  return body.slice(start, findExpressionEnd(body, start)).trim();
}

const inputAttribute = (entry, attribute) => entry.match(new RegExp(String.raw`^\s*${attribute}\s*=\s*"([^"]*)"`, "m"))?.[1];

function bbdEntries(bbdBlock, attribute) {
  const m = bbdBlock.match(new RegExp(String.raw`^\s*${attribute}\s*=\s*\{`, "m"));
  if (!m) return [];
  const open = m.index + m[0].length - 1;
  const close = findMatchingBrace(bbdBlock, open);
  if (close < 0) return [];
  const body = bbdBlock.slice(open + 1, close);
  const entries = [];
  const re = /^\s*(?:"([^"]+)"|([A-Za-z_][\w-]*))\s*=\s*\{/gm;
  let consumed = 0;
  for (let m2 = re.exec(body); m2; m2 = re.exec(body)) {
    const skipped = body.slice(consumed, m2.index);
    if ((skipped.match(/\{/g) ?? []).length !== (skipped.match(/\}/g) ?? []).length) continue;
    const entryOpen = m2.index + m2[0].length - 1;
    const entryClose = findMatchingBrace(body, entryOpen);
    if (entryClose < 0) break;
    entries.push([m2[1] ?? m2[2], body.slice(entryOpen + 1, entryClose)]);
    consumed = re.lastIndex = entryClose + 1;
  }
  return entries;
}

// meshStack passes each input to the Terraform variable of the same name in the definition's
// repository_path, which every definition in this repo sets as a literal.
function bbdInputsWithVariables(target) {
  return bbdsWithImplementation(target).flatMap(({ where, bbd, inputs, variables }) =>
    inputs.filter(([key]) => variables.has(key)).map(([key, entry]) => ({ where, bbd, key, entry, variable: variables.get(key) }))
  );
}

// Every definition whose repository_path is in this repo, with its inputs in source order and the
// code of its implementation directory.
function bbdsWithImplementation(target) {
  const found = [];
  for (const { file, content } of readCodeFiles(target)) {
    for (const [bbd, body] of extractResourceBlocks(content, "meshstack_building_block_definition")) {
      const path = body.match(/^\s*repository_path\s*=\s*"([^"$]+)"/m)?.[1];
      if (!path) continue;
      const implementation = join(ROOT, path);
      if (!existsSync(implementation)) continue;
      const code = readdirSync(implementation)
        .filter((f) => f.endsWith(".tf"))
        .map((f) => readFileSync(join(implementation, f), "utf-8"))
        .join("\n");
      found.push({ where: relative(target.path, file), bbd, inputs: bbdEntries(body, "inputs"), variables: extractVariableBlocks(code), code });
    }
  }
  return found;
}

const displayOrder = (entry) => Number(entry.match(/^\s*display_order\s*=\s*(\d+)/m)?.[1] ?? NaN);
const isAscending = (numbers) => numbers.every((n, i) => i === 0 || numbers[i - 1] <= n);

function moduleSourceDirs(file, content) {
  const dirs = [];
  for (const [name, body] of extractNamedBlocks(content, "module")) {
    const source = body.match(/^\s*source\s*=\s*"([^"]+)"/m)?.[1];
    if (!source) continue;
    const hubPath = source.match(/meshstack-hub\/\/([^?]+)/)?.[1];
    if (hubPath) dirs.push([name, join(ROOT, hubPath)]);
    else if (source.startsWith(".")) dirs.push([name, join(dirname(file), source)]);
  }
  return dirs;
}

function handsOutRelease(moduleDir) {
  const integration = moduleDir && join(moduleDir, "meshstack_integration.tf");
  if (!integration || !existsSync(integration)) return false;
  const output = extractOutputBlocks(readFileSync(integration, "utf-8")).get("building_block_definition");
  return output?.includes("version_latest_release") ?? false;
}

// A folder without a README.md is not a reference architecture; the website skips it too.
function discoverRefArchs() {
  return readdirSync(REF_ARCHS_DIR)
    .filter((name) => existsSync(join(REF_ARCHS_DIR, name, "README.md")))
    .sort()
    .map((name) => ({
      kind: "refArch",
      path: join(REF_ARCHS_DIR, name),
      hasCode: collectTfFilesRecursive(join(REF_ARCHS_DIR, name)).length > 0,
      id: name,
      dir: `reference-architectures/${name}`,
      cliArg: `--ref-arch=${name}`,
    }));
}

// Modules the code sources or registers as BBDs, plus the README.md front-matter list, which is all
// a documentation-only architecture has.
function includedModules(ra, moduleIds) {
  const paths = new Set();
  for (const file of collectTfFilesRecursive(ra.path)) {
    if (file.startsWith(join(ra.path, "e2e") + "/")) continue;
    const content = readFileSync(file, "utf-8");
    for (const m of content.matchAll(/(?<=\/\/|")modules\/([\w-]+(?:\/[\w-]+)?)/g)) paths.add(m[1]);
  }
  const frontmatter = readFileSync(join(ra.path, "README.md"), "utf-8").split(/^---\s*$/m)[1] ?? "";
  for (const m of frontmatter.matchAll(/^\s*-?\s*path:\s*(\S+)\s*$/gm)) paths.add(m[1]);

  const included = new Set();
  const unscanned = new Set();
  for (const path of paths) (moduleIds.has(path) ? included : unscanned).add(path);
  return { included: [...included].sort(byCodeUnits), unscanned: [...unscanned].sort(byCodeUnits) };
}

// ─── Marker-based ref index ──────────────────────────────────────────────────
// Check → section mapping is derived from <!-- scorecard-checks: id, ... -->
// markers in reference docs. Each marker annotates the heading that follows it.

const REF_FILES = [
  ".agents/references/module-layout.md",
  ".agents/references/meshstack-integration.md",
  ".agents/references/meshstack-resources.md",
  ".agents/references/terraform-conventions.md",
  ".agents/references/aws-backplane.md",
  ".agents/references/azure-backplane.md",
  ".agents/references/gcp-backplane.md",
  ".agents/references/stackit-backplane.md",
  ".agents/references/bbd-readme.md",
  ".agents/skills/e2e-test/SKILL.md",
  ".agents/references/reference-architectures.md",
];

function headingToAnchor(heading) {
  return heading
    .replace(/^#+\s*/, "")
    .replace(/`([^`]*)`/g, "$1")
    .toLowerCase()
    .replace(/[^\w\s-]/g, "")
    .replace(/\s+/g, "-");
}

function buildCheckToRef() {
  const checkToRef = new Map(); // checkId → {file, section}
  const errors = [];

  for (const relFile of REF_FILES) {
    const filePath = join(ROOT, relFile);
    if (!existsSync(filePath)) continue;

    const lines = readFileSync(filePath, "utf-8").split("\n");
    let pendingIds = null;

    for (const line of lines) {
      const m = line.match(/<!--\s*scorecard-checks:\s*([^-]+?)\s*-->/);
      if (m) {
        pendingIds = m[1].split(",").map((s) => s.trim()).filter(Boolean);
        continue;
      }
      if (pendingIds && /^#{1,6}\s/.test(line)) {
        const section = headingToAnchor(line);
        for (const id of pendingIds) checkToRef.set(id, { file: relFile, section });
        pendingIds = null;
      }
    }
  }

  const detectorIds = new Set(detectors.map((d) => d.id));

  for (const d of detectors) {
    if (!checkToRef.has(d.id)) {
      errors.push(`check "${d.id}" has no <!-- scorecard-checks: ... --> marker in any ref file`);
    }
  }

  for (const id of checkToRef.keys()) {
    if (!detectorIds.has(id)) {
      errors.push(`marker references unknown check "${id}" — no detector with that id`);
    }
  }

  return { checkToRef, errors };
}

// ─── Fix prompt generator ────────────────────────────────────────────────────

function generateFixPrompt(mod, failingChecks, checkToRef) {
  const lines = [];
  lines.push(
    `# Fix Scorecard Violations for \`${mod.id}\``,
    "",
    `Fix the following scorecard violations in \`${mod.dir}/\`.`,
    "After each fix re-run the scorecard to verify progress:",
    "",
    "```sh",
    `node tools/scorecard/scorecard.mjs ${mod.cliArg}`,
    "```",
    "",
    "## Failing Checks",
    "",
  );

  for (const check of failingChecks) {
    const catName = CATEGORIES[check.category].name;
    lines.push(`### ❌ \`${check.id}\` — ${check.name} [${catName}]`);
    if (check.result.detail) lines.push(`> ${check.result.detail}`);
    lines.push("");
    const ref = checkToRef.get(check.id);
    if (ref) {
      lines.push(`**Fix instructions**: [\`${ref.file}#${ref.section}\`](${ref.file}#${ref.section})`);
      lines.push("");
    }
  }

  lines.push("## Done");
  lines.push("");
  lines.push("When all checks pass, commit the changes.");
  return lines.join("\n");
}

// ─── Scoring ────────────────────────────────────────────────────────────────

function selectTargets(all, ids, noun, format) {
  if (ids.length === 0) return all;
  for (const id of ids.filter((id) => !all.some((t) => t.id === id))) {
    process.stderr.write(`Warning: ${noun} "${id}" not found — skipping.\n`);
  }
  const selected = all.filter((t) => ids.includes(t.id));
  if (selected.length === 0) {
    process.stderr.write(`Error: none of the specified ${noun}s were found. Use ${format} format.\n`);
    process.exit(1);
  }
  return selected;
}

function checkResult(target, detector, applicable) {
  if (!applicable) return { pass: null, detail: "not applicable" };
  if (target.kind === "refArch" && detector.needsCode && !target.hasCode) {
    return { pass: false, detail: typeof detector.needsCode === "string" ? detector.needsCode : "no buildingblock code yet" };
  }
  return detector.fn(target);
}

function scoreTarget(target, categories, filterCategory) {
  const categoryResults = {};

  // Always compute all categories so the per-target summary is always complete.
  // The filterCategory only controls which sections are *rendered*.
  for (const [catId, cat] of Object.entries(categories)) {
    const applicable = cat.appliesTo(target);
    const catDetectors = detectorsFor(target.kind).filter((d) => d.category === catId);
    const checks = catDetectors.map((d) => ({ ...d, result: checkResult(target, d, applicable) }));

    const applicableChecks = checks.filter((c) => c.result.pass !== null);
    const passed = applicableChecks.filter((c) => c.result.pass).length;
    const total = applicableChecks.length;
    const score = total > 0 ? Math.round((passed / total) * 100) : null;

    categoryResults[catId] = { checks, passed, total, score, applicable };
  }

  // For overall score, only include categories matching the active filter (if any).
  const allApplicableChecks = Object.entries(categoryResults)
    .filter(([catId]) => !filterCategory || catId === filterCategory)
    .flatMap(([, cr]) => cr.checks)
    .filter((c) => c.result.pass !== null);
  const passed = allApplicableChecks.filter((c) => c.result.pass).length;
  const total = allApplicableChecks.length;
  const score = total > 0 ? Math.round((passed / total) * 100) : null;

  return { mod: target, categoryResults, passed, total, score };
}

function describeIncluded({ count, failing, unscanned }) {
  const parts = [`${count} ${count === 1 ? "module" : "modules"}`];
  if (failing.length > 0) {
    const scores = failing.map(({ id, score }) => `\`${id}\` ${score}%`).join(", ");
    parts.push(`${failing.length} with failures: ${scores}`);
  }
  if (unscanned.length > 0) {
    const paths = unscanned.map((id) => `\`modules/${id}\``).join(", ");
    parts.push(`not scored: ${paths}`);
  }
  return parts.join("; ");
}

// ─── Main ───────────────────────────────────────────────────────────────────

const NOUNS = {
  module: { one: "module", many: "modules", title: "Module" },
  refArch: { one: "reference architecture", many: "reference architectures", title: "Reference Architecture" },
};

const VALUE_FLAGS = ["--category", "--provider", "--module", "--ref-arch", "--changed-since", "--output"];
const SWITCHES = new Set(["--ref-archs", "--fix"]);

function fail(message) {
  process.stderr.write(`Error: ${message}\n`);
  process.exit(1);
}

function parseArgs(argv) {
  const values = Object.fromEntries(VALUE_FLAGS.map((flag) => [flag, []]));
  const switches = new Set();
  for (const arg of argv) {
    const eq = arg.indexOf("=");
    const flag = eq < 0 ? arg : arg.slice(0, eq);
    if (eq >= 0 && VALUE_FLAGS.includes(flag)) values[flag].push(arg.slice(eq + 1));
    else if (eq < 0 && SWITCHES.has(flag)) switches.add(flag);
    else fail(`unknown argument "${arg}"`);
  }
  const opts = {
    category: values["--category"].at(-1),
    provider: values["--provider"].at(-1),
    modules: values["--module"],
    refArchs: values["--ref-arch"],
    allRefArchs: switches.has("--ref-archs"),
    changedSince: values["--changed-since"].at(-1),
    output: values["--output"].at(-1),
    fix: switches.has("--fix"),
  };
  if (opts.changedSince !== undefined && (opts.modules.length > 0 || opts.refArchs.length > 0 || opts.allRefArchs)) {
    fail("--changed-since selects its own targets; drop --module, --ref-arch and --ref-archs");
  }
  return opts;
}

function git(...args) {
  try {
    return execFileSync("git", args, { cwd: ROOT, encoding: "utf-8" }); // NOSONAR: runs in the nix dev shell, which controls PATH
  } catch {
    fail(`git ${args.join(" ")} failed`);
  }
}

function changedIds(baseRef) {
  const paths = git("diff", "--name-only", `${baseRef}...HEAD`).split("\n");
  const ids = (pattern) => [...new Set(paths.map((p) => p.match(pattern)?.[1]).filter(Boolean))].sort(byCodeUnits);
  // Provider-level files such as modules/<provider>/logo.png belong to no module.
  return { modules: ids(/^modules\/([^/]+\/[^/]+)\//), refArchs: ids(/^reference-architectures\/([^/]+)\//) };
}

function scoreKind(kind, targets, allModules, filterCategory) {
  const results = targets.map((t) => scoreTarget(t, categoriesFor(kind), filterCategory));
  if (kind === "refArch") {
    const moduleIds = new Set(allModules.map((m) => m.id));
    const moduleScores = new Map();
    const moduleScore = (id) => {
      if (!moduleScores.has(id)) {
        const mod = allModules.find((m) => m.id === id);
        moduleScores.set(id, scoreTarget(mod, categoriesFor("module")));
      }
      return moduleScores.get(id);
    };
    for (const r of results) {
      const { included, unscanned } = includedModules(r.mod, moduleIds);
      const failing = included.filter((id) => moduleScore(id).score < 100).map((id) => ({ id, score: moduleScore(id).score }));
      r.included = { count: included.length, failing, unscanned };
    }
  }
  return results;
}

function renderFixPrompts(results, checkToRef) {
  return results.map((r) => {
    const failingChecks = Object.values(r.categoryResults)
      .filter((cr) => cr.applicable)
      .flatMap((cr) => cr.checks)
      .filter((c) => c.result.pass === false);
    return failingChecks.length === 0
      ? `✅ \`${r.mod.id}\` has no failing checks.`
      : generateFixPrompt(r.mod, failingChecks, checkToRef);
  });
}

function renderReport(kind, targets, results, filterCategory) {
  const noun = NOUNS[kind];
  const categories = categoriesFor(kind);
  const lines = [];
  lines.push(`# 📊 meshstack-hub ${noun.title} Scorecard`);
  lines.push("");
  lines.push(
    `> Generated: ${new Date().toISOString().split("T")[0]} | ${noun.title}s scanned: **${targets.length}** | Categories: **${Object.keys(categories).length}**`
  );
  lines.push("");

  const categoriesToRender = filterCategory
    ? { [filterCategory]: categories[filterCategory] }
    : categories;

  lines.push(
    `## 📋 Per-${noun.title} Category Summary`,
    "",
    `Score per category per ${noun.one}. \`n/a\` = category does not apply to this ${noun.one}.`,
  );
  if (kind === "refArch") {
    lines.push("Included modules are scored by the module scorecard, and only summarized here.");
  }
  lines.push("");

  const summaryCategories = Object.entries(categories);
  const catHeaderCols = summaryCategories.map(([, cat]) => cat.name).join(" | ");
  const includedHeader = kind === "refArch" ? " Included modules |" : "";
  lines.push(
    `| ${noun.title} | Overall | ${catHeaderCols} |${includedHeader}`,
    `|--------|---------|${summaryCategories.map(() => "---").join("|")}|${kind === "refArch" ? "---|" : ""}`,
  );

  for (const r of results) {
    const overallCell = r.total > 0
      ? `${r.score >= 80 ? "🟢" : r.score >= 50 ? "🟡" : "🔴"} ${r.score}%`
      : "—";

    const catCells = summaryCategories.map(([catId]) => {
      const cr = r.categoryResults[catId];
      if (!cr || !cr.applicable) return "n/a";
      if (cr.score === null) return "—";
      const emoji = cr.score >= 80 ? "🟢" : cr.score >= 50 ? "🟡" : "🔴";
      return `${emoji} ${cr.score}%`;
    });

    const includedCell = kind === "refArch" ? ` ${describeIncluded(r.included)} |` : "";
    lines.push(`| \`${r.mod.id}\` | ${overallCell} | ${catCells.join(" | ")} |${includedCell}`);
  }
  lines.push("");

  // ─── Status Banner ───────────────────────────────────────────────────────
  const scoredModules = results.filter((r) => r.total > 0);
  const allPassing = scoredModules.length > 0 && scoredModules.every((r) => r.score === 100);
  if (allPassing) {
    lines.push(`> ✅ **All checks passing!** Every ${noun.one} meets all scorecard criteria.`);
  } else {
    const failingCount = scoredModules.filter((r) => r.score < 100).length;
    const subject = failingCount === 1 ? `1 ${noun.one} has` : `${failingCount} ${noun.many} have`;
    lines.push(`> ⚠️ **${subject} failing checks** — failing categories are expanded below.`);
  }
  lines.push("");

  for (const [catId, cat] of Object.entries(categoriesToRender)) {
    const catDetectors = detectorsFor(kind).filter((d) => d.category === catId);
    const applicableModules = results.filter((r) => r.categoryResults[catId]?.applicable);

    const categoryHasFailures = applicableModules.some((r) =>
      r.categoryResults[catId].checks.some((c) => c.result.pass === false)
    );
    const openAttr = applicableModules.length > 0 && categoryHasFailures ? " open" : "";
    const statusLabel = applicableModules.length === 0
      ? "not applicable"
      : categoryHasFailures
        ? "some checks failing"
        : "✅ all passing";

    lines.push(
      `<details${openAttr}>`,
      `<summary><strong>${cat.name}</strong> — ${statusLabel}</summary>`,
      "",
      `*${cat.description}* — applies to **${applicableModules.length}** ${noun.many}`,
      "",
    );

    if (applicableModules.length === 0) {
      lines.push(`No applicable ${noun.many}.`);
      lines.push("");
      lines.push("</details>");
      lines.push("");
      continue;
    }

    const headerCols = catDetectors.map((d) => d.emoji).join(" | ");
    lines.push(`| ${noun.title} | Score | ${headerCols} |`);
    lines.push(
      `|--------|-------|${catDetectors.map(() => "---").join("|")}|`
    );

    for (const r of applicableModules) {
      const cr = r.categoryResults[catId];
      const checkMarks = cr.checks
        .map((c) => (c.result.pass === null ? "➖" : c.result.pass ? "✅" : "❌"))
        .join(" | ");
      // A pattern-scoped category can mark every one of its checks not applicable, which leaves
      // no score to render.
      const scoreCell = cr.score === null
        ? "—"
        : `${cr.score >= 80 ? "🟢" : cr.score >= 50 ? "🟡" : "🔴"} ${cr.score}%`;
      lines.push(
        `| \`${r.mod.id}\` | ${scoreCell} | ${checkMarks} |`
      );
    }
    lines.push("");

    lines.push(`#### ${cat.name} — Summary`);
    lines.push("");
    lines.push("| Emoji | Criterion | Coverage | Status |");
    lines.push("|-------|-----------|----------|--------|");
    for (const d of catDetectors) {
      const checkApplicable = applicableModules.filter(
        (r) => r.categoryResults[catId].checks.find((c) => c.id === d.id)?.result.pass !== null
      );
      if (checkApplicable.length === 0) {
        lines.push(`| ${d.emoji} | ${d.name} | n/a | — |`);
        continue;
      }
      const passing = checkApplicable.filter(
        (r) => r.categoryResults[catId].checks.find((c) => c.id === d.id)?.result.pass === true
      ).length;
      const pct = Math.round((passing / checkApplicable.length) * 100);
      const bar = pct >= 80 ? "🟢" : pct >= 50 ? "🟡" : "🔴";
      lines.push(
        `| ${d.emoji} | ${d.name} | **${passing}/${checkApplicable.length}** | ${bar} ${pct}% |`
      );
    }
    lines.push("");
    lines.push("</details>");
    lines.push("");
  }

  // ─── Overall Summary (omit for single-target mode) ──────────────────────
  const singleModule = targets.length === 1;
  if (!singleModule) {
    lines.push("## 📈 Overall Summary");
    lines.push("");

    const scoredResults = results.filter((r) => r.total > 0);
    const totalModules = scoredResults.length;
    const avgScore = totalModules > 0
      ? Math.round(scoredResults.reduce((s, r) => s + (r.score || 0), 0) / totalModules)
      : 0;
    lines.push(`### Overall Average Score: **${avgScore}%**`);
    lines.push("");

    const high = scoredResults.filter((r) => r.score >= 80).length;
    const mid = scoredResults.filter((r) => r.score >= 50 && r.score < 80).length;
    const low = scoredResults.filter((r) => r.score < 50).length;
    lines.push(
      "### Score Distribution",
      "",
      `- 🟢 High maturity (≥80%): **${high}** ${noun.many}`,
      `- 🟡 Medium maturity (50–79%): **${mid}** ${noun.many}`,
      `- 🔴 Low maturity (<50%): **${low}** ${noun.many}`,
      "",
    );
  }

  return lines;
}

function selectChanged(baseRef, modules, refArchs, lines) {
  const changed = changedIds(baseRef);
  if (changed.modules.length === 0 && changed.refArchs.length === 0) {
    lines.push(`_No module or reference architecture changes detected relative to \`${baseRef}\`._`);
    return [];
  }
  const head = git("rev-parse", "HEAD").trim();
  lines.push(`> Scorecard run on commit \`${head}\` relative to \`${baseRef}\``, "");
  const select = (kind, all, ids, missing) => {
    for (const id of ids.filter((id) => !all.some((t) => t.id === id))) {
      lines.push(`### \`${id}\``, "", missing, "");
    }
    const targets = all.filter((t) => ids.includes(t.id));
    return targets.length > 0 ? [[kind, targets]] : [];
  };
  return [
    ...select("module", modules, changed.modules, "_Not a scored module (deleted?)._"),
    ...select("refArch", refArchs, changed.refArchs, "_Not a reference architecture (deleted?)._"),
  ];
}

function selectByOpts(opts, modules, lines) {
  if (opts.changedSince !== undefined) return selectChanged(opts.changedSince, modules, discoverRefArchs(), lines);
  if (opts.allRefArchs || opts.refArchs.length > 0) {
    return [["refArch", selectTargets(discoverRefArchs(), opts.refArchs, "reference architecture", "<name>")]];
  }
  return [["module", selectTargets(modules, opts.modules, "module", "<provider>/<service>")]];
}

function main() {
  const opts = parseArgs(process.argv.slice(2));

  const { checkToRef, errors: refErrors } = buildCheckToRef();
  if (refErrors.length > 0) {
    process.stderr.write("❌ scorecard-checks marker validation failed:\n");
    for (const e of refErrors) process.stderr.write(`  • ${e}\n`);
    process.exit(1);
  }

  const allModules = discoverModules();
  const modules = allModules.filter((m) => !opts.provider || m.provider === opts.provider);
  const lines = [];
  const selection = selectByOpts(opts, modules, lines);

  for (const [kind, targets] of selection) {
    if (opts.changedSince !== undefined) process.stderr.write(`Scoring ${targets.map((t) => t.id).join(", ")}\n`);
    const results = scoreKind(kind, targets, allModules, opts.category);
    lines.push(...(opts.fix ? renderFixPrompts(results, checkToRef) : renderReport(kind, targets, results, opts.category)));
  }

  const report = lines.join("\n") + "\n";
  if (opts.output) writeFileSync(opts.output, report);
  else process.stdout.write(report);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) main();

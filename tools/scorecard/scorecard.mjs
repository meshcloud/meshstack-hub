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
 * - Testing: applies to all modules (aspirational)
 *
 * Usage: node tools/scorecard/scorecard.mjs [--category=<name>] [--provider=<name>]
 */

import { readFileSync, existsSync, readdirSync, statSync } from "fs";
import { join, relative } from "path";

const ROOT = new URL("../../", import.meta.url).pathname.replace(/\/$/, "");
const MODULES_DIR = join(ROOT, "modules");

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
  azure_backplane: {
    id: "azure_backplane",
    name: "Azure Backplane",
    description: "Azure UAMI-based automation principal conventions",
    appliesTo: (mod) =>
      mod.provider === "azure" && existsSync(join(mod.path, "backplane")),
  },
  testing: {
    id: "testing",
    name: "Testing",
    description: "End-to-end test coverage",
    appliesTo: () => true,
  },
};

// ─── Detector functions ─────────────────────────────────────────────────────
// Each detector returns { pass: boolean, detail?: string }

const AGENTS     = (section) => ({ file: "AGENTS.md", section });
const AZURE      = (section) => ({ file: ".agents/skills/azure-backplane.md", section });
const BBD_README = (section) => ({ file: ".agents/skills/bbd-readme.md", section });

const detectors = [
  // ─── Core Structure ─────────────────────────────────────────────────────
  {
    id: "buildingblock_dir",
    category: "core",
    name: "buildingblock/ directory exists",
    emoji: "📦",
    fixRef: AGENTS("module-structure"),
    fn: (mod) => ({
      pass: existsSync(join(mod.path, "buildingblock")),
    }),
  },
  {
    id: "meshstack_integration",
    category: "core",
    name: "meshstack_integration.tf present",
    emoji: "🔗",
    fixRef: AGENTS("meshstack_integrationtf-conventions"),
    fn: (mod) => ({
      pass: existsSync(join(mod.path, "meshstack_integration.tf")),
    }),
  },
  {
    id: "app_team_readme",
    category: "core",
    name: "buildingblock/APP_TEAM_README.md present (no-integration fallback)",
    emoji: "📋",
    fixRef: AGENTS("documentation-requirements"),
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
    fixRef: AGENTS("documentation-requirements"),
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
    name: "buildingblock/logo.png included",
    emoji: "🖼️",
    fixRef: AGENTS("documentation-requirements"),
    fn: (mod) => ({
      pass: existsSync(join(mod.path, "buildingblock", "logo.png")),
    }),
  },
  {
    id: "versions_tf",
    category: "core",
    name: "buildingblock/versions.tf present",
    emoji: "📌",
    fixRef: AGENTS("module-structure"),
    fn: (mod) => ({
      pass: existsSync(join(mod.path, "buildingblock", "versions.tf")),
    }),
  },
  {
    id: "provider_pinned",
    category: "core",
    name: "Provider versions pinned (~>)",
    emoji: "🔒",
    fixRef: AGENTS("variable-conventions"),
    fn: (mod) => {
      const versionsPath = join(mod.path, "buildingblock", "versions.tf");
      if (!existsSync(versionsPath)) return { pass: false, detail: "no versions.tf" };
      const content = readFileSync(versionsPath, "utf-8");
      const versionLines = content.match(/version\s*=\s*"[^"]+"/g);
      if (!versionLines || versionLines.length === 0)
        return { pass: true, detail: "no version constraints" };
      const allPinned = versionLines.every((l) => l.includes("~>"));
      return { pass: allPinned };
    },
  },

  // ─── Integration ────────────────────────────────────────────────────────
  {
    id: "variable_hub",
    category: "integration",
    name: 'variable "hub" in integration',
    emoji: "🏷️",
    fixRef: AGENTS("shared-variable-conventions"),
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
    fixRef: AGENTS("shared-variable-conventions"),
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
    fixRef: AGENTS("exposing-building-block-definition-references"),
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
    fixRef: AGENTS("required-providers"),
    fn: (mod) => {
      const content = readIntegrationTf(mod);
      if (!content) return { pass: false, detail: "no integration file" };
      return {
        pass: /meshcloud\/meshstack/.test(content),
      };
    },
  },
  {
    id: "variable_hub_const",
    category: "integration",
    name: 'variable "hub" has const = true',
    emoji: "🔐",
    fixRef: AGENTS("shared-variable-conventions"),
    fn: (mod) => {
      const content = readIntegrationTf(mod);
      if (!content) return { pass: false, detail: "no integration file" };
      if (!/variable\s+"hub"/.test(content)) return { pass: false, detail: 'no variable "hub"' };
      return { pass: /^\s*const\s*=\s*true/m.test(content) };
    },
  },
  {
    id: "backplane_source_hub_git_ref",
    category: "integration",
    name: "backplane source uses var.hub.git_ref",
    emoji: "📎",
    fixRef: AGENTS("meshstack_integrationtf-conventions"),
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
    fixRef: AGENTS("meshstack_integrationtf-conventions"),
    fn: (mod) => {
      const content = readIntegrationTf(mod);
      if (!content) return { pass: false, detail: "no integration file" };
      const hasRefName = /ref_name\s*=/.test(content);
      if (!hasRefName) return { pass: false, detail: "no ref_name found" };
      return { pass: /ref_name\s*=\s*var\.hub\.git_ref/.test(content) };
    },
  },
  {
    id: "bbd_draft",
    category: "integration",
    name: "version_spec.draft uses var.hub.bbd_draft",
    emoji: "📋",
    fixRef: AGENTS("shared-variable-conventions"),
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
    fixRef: AGENTS("shared-variable-conventions"),
    fn: (mod) => {
      const content = readIntegrationTf(mod);
      if (!content) return { pass: false, detail: "no integration file" };
      return { pass: /tags\s*=\s*var\.meshstack\.tags/.test(content) };
    },
  },
  {
    id: "bbd_readme",
    category: "integration",
    name: "BBD readme field present",
    emoji: "📖",
    fixRef: BBD_README("standard-pattern"),
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
    fixRef: BBD_README("description"),
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
    fixRef: BBD_README("shared-responsibility-table"),
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
    fixRef: AGENTS("documentation-requirements"),
    fn: (mod) => {
      const allTf = readAllBackplaneTf(mod);
      if (!allTf) return { pass: true, detail: "no backplane" };
      return {
        pass: !/output\s+"documentation_md"/.test(allTf),
        detail: "legacy documentation_md output found — move content to BBD readme and backplane/README.md",
      };
    },
  },

  // ─── Azure Backplane ────────────────────────────────────────────────────
  {
    id: "azure_uses_uami",
    category: "azure_backplane",
    name: "Uses azurerm_user_assigned_identity",
    emoji: "🪪",
    fixRef: AZURE("implementation-pattern"),
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
    fixRef: AZURE("what-to-avoid"),
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
    fixRef: AZURE("what-to-avoid"),
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
    fixRef: AZURE("what-to-avoid"),
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
    fixRef: AZURE("implementation-pattern"),
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
    fixRef: AZURE("backplane-variables-azure"),
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
    fixRef: AZURE("what-to-avoid"),
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
    fixRef: AZURE("backplane-outputs-azure"),
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
    name: "Integration has azure_resource_group_name & azure_location",
    emoji: "📍",
    fixRef: AZURE("meshstack_integrationtf-wiring-azure"),
    fn: (mod) => {
      const content = readIntegrationTf(mod);
      if (!content) return { pass: false, detail: "no integration file" };
      const hasRg = /variable\s+"azure_resource_group_name"/.test(content);
      const hasLocation = /variable\s+"azure_location"/.test(content);
      return {
        pass: hasRg && hasLocation,
        detail: !hasRg ? "missing azure_resource_group_name" : "missing azure_location",
      };
    },
  },

  // ─── Testing ────────────────────────────────────────────────────────────
  {
    id: "backplane",
    category: "testing",
    name: "backplane/ directory (optional tier)",
    emoji: "⚙️",
    fixRef: AGENTS("module-structure"),
    fn: (mod) => ({
      pass: existsSync(join(mod.path, "backplane")),
    }),
  },
  {
    id: "e2e_tests",
    category: "testing",
    name: "e2e/ test directory exists",
    emoji: "🧪",
    fixRef: AGENTS("end-to-end-testing"),
    fn: (mod) => ({
      pass: existsSync(join(mod.path, "e2e")),
    }),
  },
  {
    id: "e2e_tftest",
    category: "testing",
    name: "e2e/ contains .tftest.hcl files",
    emoji: "✅",
    fixRef: AGENTS("e2etests-tftesthcl-conventions"),
    fn: (mod) => {
      const e2eDir = join(mod.path, "e2e", "tests");
      if (!existsSync(e2eDir)) return { pass: false };
      const files = readdirSync(e2eDir);
      return { pass: files.some((f) => f.endsWith(".tftest.hcl")) };
    },
  },
];

// ─── Helpers ────────────────────────────────────────────────────────────────

function readIntegrationTf(mod) {
  const p = join(mod.path, "meshstack_integration.tf");
  if (!existsSync(p)) return null;
  return readFileSync(p, "utf-8");
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

function extractBBDReadmeContent(content) {
  // Match: readme = [chomp(] <<[-]MARKER\n...content...\nMARKER
  const m = content.match(/readme\s*=\s*(?:chomp\s*\(\s*)?<<-?([A-Za-z_]+)\s*\n([\s\S]*?)\n[ \t]*\1\b/);
  if (!m) return null;
  const lines = m[2].split("\n");
  const nonEmpty = lines.filter((l) => l.trim().length > 0);
  if (nonEmpty.length === 0) return "";
  const minIndent = Math.min(...nonEmpty.map((l) => (l.match(/^(\s*)/) || ["", ""])[1].length));
  return lines.map((l) => l.slice(minIndent)).join("\n").trim();
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
          provider,
          service,
          path: modulePath,
          id: `${provider}/${service}`,
        });
      }
    }
  }

  return modules.sort((a, b) => a.id.localeCompare(b.id));
}

// ─── Fix prompt generator ────────────────────────────────────────────────────

function generateFixPrompt(mod, failingChecks) {
  const lines = [];
  lines.push(`# Fix Scorecard Violations for \`${mod.id}\``);
  lines.push("");
  lines.push(`Fix the following scorecard violations in \`modules/${mod.id}/\`.`);
  lines.push("After each fix re-run the scorecard to verify progress:");
  lines.push("");
  lines.push("```sh");
  lines.push(`node tools/scorecard/scorecard.mjs --module=${mod.id}`);
  lines.push("```");
  lines.push("");
  lines.push("## Failing Checks");
  lines.push("");

  for (const check of failingChecks) {
    const catName = CATEGORIES[check.category].name;
    lines.push(`### ❌ \`${check.id}\` — ${check.name} [${catName}]`);
    if (check.result.detail) lines.push(`> ${check.result.detail}`);
    lines.push("");
    const ref = check.fixRef;
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

// ─── Main ───────────────────────────────────────────────────────────────────

function main() {
  const args = process.argv.slice(2);
  const filterCategory = args.find((a) => a.startsWith("--category="))?.split("=")[1];
  const filterProvider = args.find((a) => a.startsWith("--provider="))?.split("=")[1];
  const filterModule = args.find((a) => a.startsWith("--module="))?.split("=")[1];
  const fixMode = args.includes("--fix");

  let modules = discoverModules();
  if (filterProvider) {
    modules = modules.filter((m) => m.provider === filterProvider);
  }
  if (filterModule) {
    modules = modules.filter((m) => m.id === filterModule);
    if (modules.length === 0) {
      process.stderr.write(`Error: module "${filterModule}" not found. Use <provider>/<service> format.\n`);
      process.exit(1);
    }
  }

  const results = [];

  for (const mod of modules) {
    const categoryResults = {};

    // Always compute all categories so the per-module summary is always complete.
    // The filterCategory only controls which sections are *rendered*.
    for (const [catId, cat] of Object.entries(CATEGORIES)) {
      const applicable = cat.appliesTo(mod);
      const catDetectors = detectors.filter((d) => d.category === catId);
      const checks = catDetectors.map((d) => ({
        ...d,
        result: applicable ? d.fn(mod) : { pass: null, detail: "not applicable" },
      }));

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
    const totalPassed = allApplicableChecks.filter((c) => c.result.pass).length;
    const totalChecks = allApplicableChecks.length;
    const overallScore = totalChecks > 0 ? Math.round((totalPassed / totalChecks) * 100) : null;

    results.push({ mod, categoryResults, passed: totalPassed, total: totalChecks, score: overallScore });
  }

  // ─── Fix mode ───────────────────────────────────────────────────────────
  if (fixMode) {
    for (const r of results) {
      const failingChecks = Object.values(r.categoryResults)
        .filter((cr) => cr.applicable)
        .flatMap((cr) => cr.checks)
        .filter((c) => c.result.pass === false);

      if (failingChecks.length === 0) {
        console.log(`✅ \`${r.mod.id}\` has no failing checks.`);
      } else {
        console.log(generateFixPrompt(r.mod, failingChecks));
      }
    }
    return;
  }

  // ─── Render Report ──────────────────────────────────────────────────────
  const lines = [];
  lines.push("# 📊 meshstack-hub Module Scorecard");
  lines.push("");
  lines.push(
    `> Generated: ${new Date().toISOString().split("T")[0]} | Modules scanned: **${modules.length}** | Categories: **${Object.keys(CATEGORIES).length}**`
  );
  lines.push("");

  const categoriesToRender = filterCategory
    ? { [filterCategory]: CATEGORIES[filterCategory] }
    : CATEGORIES;

  // ─── Per-Module Category Summary (omit for single-module mode) ───────────
  lines.push("## 📋 Per-Module Category Summary");
  lines.push("");
  lines.push("Score per category per building block. `n/a` = category does not apply to this module.");
  lines.push("");

  const summaryCategories = Object.entries(CATEGORIES);
  const catHeaderCols = summaryCategories.map(([, cat]) => cat.name).join(" | ");
  lines.push(`| Module | Overall | ${catHeaderCols} |`);
  lines.push(`|--------|---------|${summaryCategories.map(() => "---").join("|")}|`);

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

    lines.push(`| \`${r.mod.id}\` | ${overallCell} | ${catCells.join(" | ")} |`);
  }
  lines.push("");

  for (const [catId, cat] of Object.entries(categoriesToRender)) {
    const catDetectors = detectors.filter((d) => d.category === catId);
    const applicableModules = results.filter((r) => r.categoryResults[catId]?.applicable);

    lines.push(`## ${cat.name}`);
    lines.push("");
    lines.push(`*${cat.description}* — applies to **${applicableModules.length}** modules`);
    lines.push("");

    if (applicableModules.length === 0) {
      lines.push("No applicable modules.");
      lines.push("");
      continue;
    }

    const headerCols = catDetectors.map((d) => d.emoji).join(" | ");
    lines.push(`| Module | Score | ${headerCols} |`);
    lines.push(
      `|--------|-------|${catDetectors.map(() => "---").join("|")}|`
    );

    for (const r of applicableModules) {
      const cr = r.categoryResults[catId];
      const checkMarks = cr.checks
        .map((c) => (c.result.pass === null ? "➖" : c.result.pass ? "✅" : "❌"))
        .join(" | ");
      const scoreEmoji = cr.score >= 80 ? "🟢" : cr.score >= 50 ? "🟡" : "🔴";
      lines.push(
        `| \`${r.mod.id}\` | ${scoreEmoji} ${cr.score}% | ${checkMarks} |`
      );
    }
    lines.push("");

    // Per-criterion summary omitted for single-module mode (redundant with the table row above)
    lines.push(`### ${cat.name} — Summary`);
    lines.push("");
    lines.push("| Emoji | Criterion | Coverage | Status |");
    lines.push("|-------|-----------|----------|--------|");
    for (const d of catDetectors) {
      const passing = applicableModules.filter(
        (r) => r.categoryResults[catId].checks.find((c) => c.id === d.id)?.result.pass
      ).length;
      const pct = Math.round((passing / applicableModules.length) * 100);
      const bar = pct >= 80 ? "🟢" : pct >= 50 ? "🟡" : "🔴";
      lines.push(
        `| ${d.emoji} | ${d.name} | **${passing}/${applicableModules.length}** | ${bar} ${pct}% |`
      );
    }
    lines.push("");
  }

  // ─── Overall Summary (omit for single-module mode) ──────────────────────
  const singleModule = modules.length === 1;
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
    lines.push("### Score Distribution");
    lines.push("");
    lines.push(`- 🟢 High maturity (≥80%): **${high}** modules`);
    lines.push(`- 🟡 Medium maturity (50–79%): **${mid}** modules`);
    lines.push(`- 🔴 Low maturity (<50%): **${low}** modules`);
    lines.push("");
  }

  console.log(lines.join("\n"));
}

main();

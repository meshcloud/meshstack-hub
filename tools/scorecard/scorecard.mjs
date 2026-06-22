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
  stackit_backplane: {
    id: "stackit_backplane",
    name: "STACKIT Backplane",
    description: "STACKIT WIF-based automation principal conventions",
    appliesTo: (mod) =>
      mod.provider === "stackit" && existsSync(join(mod.path, "backplane")),
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
    name: "buildingblock/logo.png included",
    emoji: "🖼️",
    fn: (mod) => ({
      pass: existsSync(join(mod.path, "buildingblock", "logo.png")),
    }),
  },
  {
    id: "versions_tf",
    category: "core",
    name: "buildingblock/versions.tf present",
    emoji: "📌",
    fn: (mod) => ({
      pass: existsSync(join(mod.path, "buildingblock", "versions.tf")),
    }),
  },
  {
    id: "provider_pinned",
    category: "core",
    name: "Provider versions use minimum constraint (>=)",
    emoji: "🔒",
    fn: (mod) => {
      const versionsPath = join(mod.path, "buildingblock", "versions.tf");
      if (!existsSync(versionsPath)) return { pass: false, detail: "no versions.tf" };
      const content = readFileSync(versionsPath, "utf-8");
      const versionLines = content.match(/version\s*=\s*"[^"]+"/g);
      if (!versionLines || versionLines.length === 0)
        return { pass: true, detail: "no version constraints" };
      const allMinimum = versionLines.every((l) => l.includes(">=") && !l.includes("~>"));
      return { pass: allMinimum };
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
    id: "stackit_provider_oidc",
    category: "stackit_backplane",
    name: "Buildingblock provider uses use_oidc = true",
    emoji: "⚡",
    fn: (mod) => {
      const providerTf = join(mod.path, "buildingblock", "provider.tf");
      if (!existsSync(providerTf)) return { pass: false, detail: "no provider.tf" };
      const content = readFileSync(providerTf, "utf-8");
      return {
        pass: /use_oidc\s*=\s*true/.test(content),
        detail: "provider.tf does not use use_oidc = true — use WIF instead of service_account_key",
      };
    },
  },

  // ─── Testing ────────────────────────────────────────────────────────────
  {
    id: "backplane",
    category: "testing",
    name: "backplane/ directory (optional tier)",
    emoji: "⚙️",
    fn: (mod) => ({
      pass: existsSync(join(mod.path, "backplane")),
    }),
  },
  {
    id: "e2e_tests",
    category: "testing",
    name: "e2e/ test directory exists",
    emoji: "🧪",
    fn: (mod) => ({
      pass: existsSync(join(mod.path, "e2e")),
    }),
  },
  {
    id: "e2e_tftest",
    category: "testing",
    name: "e2e/ contains .tftest.hcl files",
    emoji: "✅",
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

// ─── Marker-based ref index ──────────────────────────────────────────────────
// Check → section mapping is derived from <!-- scorecard-checks: id, ... -->
// markers in reference docs. Each marker annotates the heading that follows it.

const REF_FILES = [
  "AGENTS.md",
  ".agents/references/azure-backplane.md",
  ".agents/references/stackit-backplane.md",
  ".agents/references/bbd-readme.md",
  ".agents/skills/e2e-test/SKILL.md",
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

// ─── Main ───────────────────────────────────────────────────────────────────

function main() {
  const args = process.argv.slice(2);
  const filterCategory = args.find((a) => a.startsWith("--category="))?.split("=")[1];
  const filterProvider = args.find((a) => a.startsWith("--provider="))?.split("=")[1];
  const filterModules = args.filter((a) => a.startsWith("--module=")).map((a) => a.split("=")[1]);
  const fixMode = args.includes("--fix");

  const { checkToRef, errors: refErrors } = buildCheckToRef();
  if (refErrors.length > 0) {
    process.stderr.write("❌ scorecard-checks marker validation failed:\n");
    for (const e of refErrors) process.stderr.write(`  • ${e}\n`);
    process.exit(1);
  }

  let modules = discoverModules();
  if (filterProvider) {
    modules = modules.filter((m) => m.provider === filterProvider);
  }
  if (filterModules.length > 0) {
    const unknown = filterModules.filter((id) => !modules.some((m) => m.id === id));
    for (const id of unknown) {
      process.stderr.write(`Warning: module "${id}" not found — skipping.\n`);
    }
    modules = modules.filter((m) => filterModules.includes(m.id));
    if (modules.length === 0) {
      process.stderr.write(`Error: none of the specified modules were found. Use <provider>/<service> format.\n`);
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
        console.log(generateFixPrompt(r.mod, failingChecks, checkToRef));
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

  // ─── Status Banner ───────────────────────────────────────────────────────
  const scoredModules = results.filter((r) => r.total > 0);
  const allPassing = scoredModules.length > 0 && scoredModules.every((r) => r.score === 100);
  if (allPassing) {
    lines.push("> ✅ **All checks passing!** This module meets all scorecard criteria.");
  } else {
    const failingCount = scoredModules.filter((r) => r.score < 100).length;
    const noun = failingCount === 1 ? "1 module has" : `${failingCount} modules have`;
    lines.push(`> ⚠️ **${noun} failing checks** — failing categories are expanded below.`);
  }
  lines.push("");

  for (const [catId, cat] of Object.entries(categoriesToRender)) {
    const catDetectors = detectors.filter((d) => d.category === catId);
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

    lines.push(`<details${openAttr}>`);
    lines.push(`<summary><strong>${cat.name}</strong> — ${statusLabel}</summary>`);
    lines.push("");
    lines.push(`*${cat.description}* — applies to **${applicableModules.length}** modules`);
    lines.push("");

    if (applicableModules.length === 0) {
      lines.push("No applicable modules.");
      lines.push("");
      lines.push("</details>");
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

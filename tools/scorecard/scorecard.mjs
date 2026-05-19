#!/usr/bin/env node
/**
 * meshstack-hub Module Scorecard
 *
 * Scans every building block module and assesses maturity based on
 * deterministic criteria derived from the repository conventions.
 *
 * Usage: node tools/scorecard/scorecard.mjs
 */

import { readFileSync, existsSync, readdirSync, statSync } from "fs";
import { join, relative } from "path";

const ROOT = new URL("../../", import.meta.url).pathname.replace(/\/$/, "");
const MODULES_DIR = join(ROOT, "modules");

// ─── Detector functions ─────────────────────────────────────────────────────
// Each detector returns { pass: boolean, detail?: string }

const detectors = [
  {
    id: "buildingblock_dir",
    name: "buildingblock/ directory exists",
    emoji: "📦",
    fn: (mod) => ({
      pass: existsSync(join(mod.path, "buildingblock")),
    }),
  },
  {
    id: "meshstack_integration",
    name: "meshstack_integration.tf present",
    emoji: "🔗",
    fn: (mod) => ({
      pass: existsSync(join(mod.path, "meshstack_integration.tf")),
    }),
  },
  {
    id: "readme_frontmatter",
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
    name: "buildingblock/logo.png included",
    emoji: "🖼️",
    fn: (mod) => ({
      pass: existsSync(join(mod.path, "buildingblock", "logo.png")),
    }),
  },
  {
    id: "variable_hub",
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
    id: "variable_hub_const",
    name: 'variable "hub" has const = true',
    emoji: "🔐",
    fn: (mod) => {
      const content = readIntegrationTf(mod);
      if (!content) return { pass: false, detail: "no integration file" };
      if (!/variable\s+"hub"/.test(content)) return { pass: false, detail: 'no variable "hub"' };
      // const = true must appear somewhere in the file (it's only valid on a variable)
      return { pass: /^\s*const\s*=\s*true/m.test(content) };
    },
  },
  {
    id: "backplane_source_hub_git_ref",
    name: "backplane source uses var.hub.git_ref",
    emoji: "📎",
    fn: (mod) => {
      const content = readIntegrationTf(mod);
      if (!content) return { pass: false, detail: "no integration file" };
      // If no backplane module source exists, treat as passing (backplane is optional)
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
    name: "ref_name uses var.hub.git_ref",
    emoji: "🔀",
    fn: (mod) => {
      const content = readIntegrationTf(mod);
      if (!content) return { pass: false, detail: "no integration file" };
      // Check that ref_name references var.hub.git_ref, not a hardcoded string
      const hasRefName = /ref_name\s*=/.test(content);
      if (!hasRefName) return { pass: false, detail: "no ref_name found" };
      return { pass: /ref_name\s*=\s*var\.hub\.git_ref/.test(content) };
    },
  },
  {
    id: "bbd_draft",
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
    name: "BBD readme field present",
    emoji: "📖",
    fn: (mod) => {
      const content = readIntegrationTf(mod);
      if (!content) return { pass: false, detail: "no integration file" };
      return { pass: /readme\s*=/.test(content) };
    },
  },
  {
    id: "backplane",
    name: "backplane/ directory (optional tier)",
    emoji: "⚙️",
    fn: (mod) => ({
      pass: existsSync(join(mod.path, "backplane")),
    }),
  },
  {
    id: "e2e_tests",
    name: "e2e/ test directory exists",
    emoji: "🧪",
    fn: (mod) => ({
      pass: existsSync(join(mod.path, "e2e")),
    }),
  },
  {
    id: "e2e_tftest",
    name: "e2e/ contains .tftest.hcl files",
    emoji: "✅",
    fn: (mod) => {
      const e2eDir = join(mod.path, "e2e", "tests");
      if (!existsSync(e2eDir)) return { pass: false };
      const files = readdirSync(e2eDir);
      return { pass: files.some((f) => f.endsWith(".tftest.hcl")) };
    },
  },
  {
    id: "versions_tf",
    name: "buildingblock/versions.tf present",
    emoji: "📌",
    fn: (mod) => ({
      pass: existsSync(join(mod.path, "buildingblock", "versions.tf")),
    }),
  },
  {
    id: "provider_pinned",
    name: "Provider versions pinned (~>)",
    emoji: "🔒",
    fn: (mod) => {
      const versionsPath = join(mod.path, "buildingblock", "versions.tf");
      if (!existsSync(versionsPath)) return { pass: false, detail: "no versions.tf" };
      const content = readFileSync(versionsPath, "utf-8");
      // Check if there are version constraints and they use ~>
      const versionLines = content.match(/version\s*=\s*"[^"]+"/g);
      if (!versionLines || versionLines.length === 0)
        return { pass: true, detail: "no version constraints" };
      const allPinned = versionLines.every((l) => l.includes("~>"));
      return { pass: allPinned };
    },
  },
];

// ─── Helpers ────────────────────────────────────────────────────────────────

function readIntegrationTf(mod) {
  const p = join(mod.path, "meshstack_integration.tf");
  if (!existsSync(p)) return null;
  return readFileSync(p, "utf-8");
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
      // Only consider directories that have a buildingblock/ subdirectory
      // or a meshstack_integration.tf (these are actual modules)
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

// ─── Main ───────────────────────────────────────────────────────────────────

function main() {
  const modules = discoverModules();
  const results = [];

  for (const mod of modules) {
    const checks = detectors.map((d) => ({
      ...d,
      result: d.fn(mod),
    }));
    const passed = checks.filter((c) => c.result.pass).length;
    const total = checks.length;
    const score = Math.round((passed / total) * 100);
    results.push({ mod, checks, passed, total, score });
  }

  // ─── Render Report ──────────────────────────────────────────────────────
  const lines = [];
  lines.push("# 📊 meshstack-hub Module Scorecard");
  lines.push("");
  lines.push(
    `> Generated: ${new Date().toISOString().split("T")[0]} | Modules scanned: **${modules.length}** | Criteria: **${detectors.length}**`
  );
  lines.push("");

  // Legend
  lines.push("## Legend");
  lines.push("");
  lines.push("| Emoji | Criterion |");
  lines.push("|-------|-----------|");
  for (const d of detectors) {
    lines.push(`| ${d.emoji} | ${d.name} |`);
  }
  lines.push("");

  // Per-module results table
  lines.push("## Module Scores");
  lines.push("");

  const headerCols = detectors.map((d) => d.emoji).join(" | ");
  lines.push(`| Module | Score | ${headerCols} |`);
  lines.push(
    `|--------|-------|${detectors.map(() => "---").join("|")}|`
  );

  for (const r of results) {
    const checkMarks = r.checks
      .map((c) => (c.result.pass ? "✅" : "❌"))
      .join(" | ");
    const scoreEmoji = r.score >= 80 ? "🟢" : r.score >= 50 ? "🟡" : "🔴";
    lines.push(
      `| \`${r.mod.id}\` | ${scoreEmoji} ${r.score}% | ${checkMarks} |`
    );
  }
  lines.push("");

  // ─── Summary Statistics ─────────────────────────────────────────────────
  lines.push("## 📈 Summary Statistics");
  lines.push("");

  const totalModules = results.length;

  for (const d of detectors) {
    const passing = results.filter(
      (r) => r.checks.find((c) => c.id === d.id).result.pass
    ).length;
    const pct = Math.round((passing / totalModules) * 100);
    const bar = pct >= 80 ? "🟢" : pct >= 50 ? "🟡" : "🔴";
    lines.push(
      `| ${d.emoji} | ${d.name} | **${passing}/${totalModules}** modules | ${bar} ${pct}% |`
    );
  }

  // Table header for summary
  const summaryHeader = [
    "| Emoji | Criterion | Coverage | Status |",
    "|-------|-----------|----------|--------|",
  ];
  // Re-insert header before data rows
  const summaryStart = lines.lastIndexOf("## 📈 Summary Statistics");
  lines.splice(summaryStart + 2, 0, ...summaryHeader);

  lines.push("");

  // Overall average
  const avgScore = Math.round(
    results.reduce((s, r) => s + r.score, 0) / totalModules
  );
  lines.push(`### Overall Average Score: **${avgScore}%**`);
  lines.push("");

  // Score distribution
  const high = results.filter((r) => r.score >= 80).length;
  const mid = results.filter((r) => r.score >= 50 && r.score < 80).length;
  const low = results.filter((r) => r.score < 50).length;
  lines.push("### Score Distribution");
  lines.push("");
  lines.push(`- 🟢 High maturity (≥80%): **${high}** modules`);
  lines.push(`- 🟡 Medium maturity (50–79%): **${mid}** modules`);
  lines.push(`- 🔴 Low maturity (<50%): **${low}** modules`);
  lines.push("");

  console.log(lines.join("\n"));
}

main();

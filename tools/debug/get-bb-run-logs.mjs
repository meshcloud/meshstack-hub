#!/usr/bin/env node
// get-bb-run-logs.mjs — fetch step-by-step building block run logs from meshStack
// No external npm dependencies required (uses Node 18+ built-in fetch).
//
// Usage:
//   node tools/debug/get-bb-run-logs.mjs <building-block-uuid>
//
// Prerequisites: source setup-env.sh in meshstack-smoke-test first to export
//   MESHSTACK_ENDPOINT, MESHSTACK_API_KEY, and MESHSTACK_API_SECRET.

// ── color helpers ─────────────────────────────────────────────────────────────

const tty = process.stdout.isTTY;
const esc = tty ? (code, s) => `\x1b[${code}m${s}\x1b[0m` : (_, s) => s;

const c = {
  bold:   s => esc('1',    s),
  dim:    s => esc('2',    s),
  red:    s => esc('31',   s),
  green:  s => esc('32',   s),
  yellow: s => esc('33',   s),
  cyan:   s => esc('36',   s),
  error:  s => esc('1;31', s),
  warn:   s => esc('33',   s),
  ok:     s => esc('32',   s),
  header: s => esc('1;34', s),
};

function log(msg)  { console.log(msg); }
function err(msg)  { console.error(c.error('ERROR ') + msg); }
function warn(msg) { console.warn(c.warn('WARN  ') + msg); }

// ── argument / environment checks ─────────────────────────────────────────────

const BB_UUID = process.argv[2];

if (!BB_UUID) {
  console.error(c.bold('Usage: node tools/debug/get-bb-run-logs.mjs <building-block-uuid>'));
  process.exit(1);
}

const { MESHSTACK_ENDPOINT, MESHSTACK_API_KEY, MESHSTACK_API_SECRET } = process.env;

if (!MESHSTACK_ENDPOINT || !MESHSTACK_API_KEY || !MESHSTACK_API_SECRET) {
  err('MESHSTACK_ENDPOINT, MESHSTACK_API_KEY and MESHSTACK_API_SECRET must be set.');
  err('Run: source ../meshstack-smoke-test/setup-env.sh');
  process.exit(1);
}

// ── meshStack helpers ─────────────────────────────────────────────────────────

const BB_RUN_ACCEPT = 'application/vnd.meshcloud.api.meshbuildingblockrun.v1.hal+json';

async function meshLogin() {
  const body = new URLSearchParams({
    grant_type: 'client_credentials',
    client_id: MESHSTACK_API_KEY,
    client_secret: MESHSTACK_API_SECRET,
  });
  const res = await fetch(`${MESHSTACK_ENDPOINT}/api/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: body.toString(),
  });
  if (!res.ok) throw new Error(`meshStack login failed: ${res.status} ${await res.text()}`);
  const { access_token } = await res.json();
  return access_token;
}

async function meshGet(token, url, accept) {
  const fullUrl = url.startsWith('http') ? url : `${MESHSTACK_ENDPOINT}${url}`;
  const res = await fetch(fullUrl, {
    headers: { Authorization: `Bearer ${token}`, Accept: accept },
  });
  if (!res.ok) throw new Error(`GET ${url} failed: ${res.status} ${await res.text()}`);
  return res.json();
}

// ── main ──────────────────────────────────────────────────────────────────────

async function main() {
  log(c.dim(`Authenticating with meshStack at ${MESHSTACK_ENDPOINT}...`));
  const token = await meshLogin();

  log(c.dim(`Fetching runs for building block ${BB_UUID}...`));
  const runsData = await meshGet(
    token,
    `/api/meshobjects/meshbuildingblockruns?buildingBlockUuid=${BB_UUID}`,
    BB_RUN_ACCEPT,
  );

  const runs = runsData._embedded?.meshBuildingBlockRuns ?? [];

  if (runs.length === 0) {
    warn(`No runs found for building block UUID: ${BB_UUID}`);
    process.exit(0);
  }

  log(c.bold(`\nFound ${runs.length} run(s) for building block ${BB_UUID}\n`));

  let anyFailed = false;

  for (const run of runs) {
    const runNumber = run.spec?.runNumber ?? '?';
    const status    = run.status?.status ?? 'UNKNOWN';
    const logsHref  = run._links?.downloadLogs?.href;

    const statusColor = status === 'SUCCEEDED' ? c.ok(status)
                      : status === 'FAILED'    ? c.error(status)
                      : c.yellow(status);

    log(c.header(`=== Run #${runNumber} [${statusColor}] ===`));

    if (status === 'FAILED') anyFailed = true;

    if (!logsHref) {
      warn(`  No downloadLogs link available for run #${runNumber}`);
      continue;
    }

    let logsData;
    try {
      logsData = await meshGet(token, logsHref, BB_RUN_ACCEPT);
    } catch (e) {
      err(`  Failed to fetch logs for run #${runNumber}: ${e.message}`);
      continue;
    }

    const steps = logsData.steps ?? [];
    if (steps.length === 0) {
      log(c.dim('  (no steps)'));
      continue;
    }

    for (const step of steps) {
      const stepName   = step.displayName ?? step.name ?? '(unnamed step)';
      const stepStatus = step.status ?? 'UNKNOWN';
      const msg        = step.systemMessage ?? '';

      const stepColor = stepStatus === 'SUCCEEDED' ? c.ok(stepStatus)
                      : stepStatus === 'FAILED'    ? c.error(stepStatus)
                      : c.yellow(stepStatus);

      log(c.bold(`--- ${stepName} [${stepColor}] ---`));
      if (msg) {
        log(msg);
      } else {
        log(c.dim('  (no system message)'));
      }
    }

    log('');
  }

  process.exit(anyFailed ? 1 : 0);
}

main().catch(e => {
  err(e.message);
  process.exit(1);
});

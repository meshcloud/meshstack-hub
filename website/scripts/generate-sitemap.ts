/**
 * Generates public/sitemap.xml from static app routes and dynamic routes
 * derived from the generated JSON data files.
 *
 * Run via:  npm run generate-sitemap
 */
import { writeFileSync, readFileSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = resolve(__dirname, '..');

function readJson<T>(relativePath: string): T {
  return JSON.parse(readFileSync(resolve(root, relativePath), 'utf-8')) as T;
}

// ── Load generated data ────────────────────────────────────────────────────
const { templates } = readJson<{ templates: { id: string; platformType: string }[] }>(
  'src/generated/templates.json'
);
const platforms = readJson<{ platformType: string }[]>('src/generated/platform.json');
const { referenceArchitectures } = readJson<{ referenceArchitectures: { id: string }[] }>(
  'src/generated/reference-architectures.json'
);

// ── Base URL ───────────────────────────────────────────────────────────────
const BASE_URL = 'https://hub.meshcloud.io';

// ── Collect all URLs ───────────────────────────────────────────────────────
const urls: string[] = [];

const add = (path: string): void => {
  urls.push(`${BASE_URL}${path}`);
};

// Static routes (from app.routes.ts)
add('/');
add('/reference-architectures');

// Dynamic: /platforms/:type  and  /platforms/:type/integrate
for (const p of platforms) {
  add(`/platforms/${p.platformType}`);
  add(`/platforms/${p.platformType}/integrate`);
}

// Dynamic: /platforms/:type/definitions/:id  and  /definitions/:id
for (const t of templates) {
  add(`/platforms/${t.platformType}/definitions/${t.id}`);
  add(`/definitions/${t.id}`);
}

// Dynamic: /reference-architectures/:id
for (const ra of referenceArchitectures) {
  add(`/reference-architectures/${ra.id}`);
}

// ── Build XML ──────────────────────────────────────────────────────────────
const xml =
  `<?xml version="1.0" encoding="UTF-8"?>\n` +
  `<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n` +
  urls
    .map(loc => `  <url>\n    <loc>${loc}</loc>\n  </url>`)
    .join('\n') +
  `\n</urlset>\n`;

const outPath = resolve(root, 'public', 'sitemap.xml');
writeFileSync(outPath, xml, 'utf-8');
console.log(`✅  sitemap.xml written to ${outPath} (${urls.length} URLs)`);

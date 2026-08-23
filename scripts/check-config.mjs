// Guards the mistake that shipped in 1.0.0: safeDomain replaces the set of
// URLs that stay inside the app, it does not add to it. Listing only the SSO
// domains left the app's own host classified as external, so every internal
// link was handed to the system browser.
//
// Reads the config pake generated for the build just run and asserts the app
// can still navigate to itself.
import { readFileSync, existsSync } from 'node:fs';

const GENERATED = 'node_modules/pake-cli/src-tauri/.pake/pake.json';

const app = JSON.parse(readFileSync('app.json', 'utf8'));
const home = new URL(app.url);

if (!existsSync(GENERATED)) {
  console.error(`warning: ${GENERATED} not found — cannot verify internal navigation`);
  process.exit(0);
}

const generated = JSON.parse(readFileSync(GENERATED, 'utf8'));
const window = generated.windows?.[0] ?? generated;
const pattern = window.internal_url_regex;

// An empty regex is pake's default, which keeps the app's own host internal.
if (!pattern) {
  console.log('internal_url_regex is unset — pake keeps the origin host internal by default');
  process.exit(0);
}

const probes = [home.href, new URL('/following', home).href, new URL('/shots/1', home).href];
const failed = probes.filter((url) => !new RegExp(pattern).test(url));

if (failed.length > 0) {
  console.error(`internal_url_regex does not match the app's own URLs, so links to ${home.host} would open in the system browser:`);
  for (const url of failed) console.error(`  external: ${url}`);
  console.error(`regex: ${pattern}`);
  console.error(`fix: include ${home.host} in safeDomain`);
  process.exit(1);
}

console.log(`internal_url_regex keeps ${home.host} inside the app (${probes.length} URLs checked)`);

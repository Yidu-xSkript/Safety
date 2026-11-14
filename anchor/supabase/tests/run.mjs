// Runs the migration and supabase/tests/rls.sql on an in-process Postgres (PGlite). No Docker, no Supabase.
//   PGLITE_DIR=<folder with node_modules/@electric-sql/pglite> node supabase/tests/run.mjs
// Install once anywhere outside the repo:  npm install @electric-sql/pglite
// (On a real Supabase project, run the migration only; stubs.sql is for this runner.)
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const dir = process.env.PGLITE_DIR;
if (!dir) {
  console.error('Set PGLITE_DIR to a folder where `npm install @electric-sql/pglite` was run.');
  process.exit(2);
}
const { PGlite } = await import(pathToFileURL(join(dir, 'node_modules/@electric-sql/pglite/dist/index.js')).href);
const read = (p) => readFileSync(join(here, p), 'utf8');

const db = new PGlite();
await db.exec(read('stubs.sql'));
await db.exec(process.env.MIGRATION ? readFileSync(process.env.MIGRATION, 'utf8') : read('../migrations/0001_init.sql'));
console.log('ok   migration applies');

// Sections are marked "-- @test name" and share state, so they run in order.
const sections = read('rls.sql').split(/^-- @test /m).slice(1);
let failed = 0;
for (const s of sections) {
  const nl = s.indexOf('\n');
  const name = s.slice(0, nl).trim();
  try {
    await db.exec(s.slice(nl + 1));
    console.log(`ok   ${name}`);
  } catch (e) {
    failed++;
    console.log(`FAIL ${name}\n     ${String(e.message).split('\n')[0]}`);
    await db.exec('reset role').catch(() => {});
  }
}
console.log(failed ? `\n${failed} of ${sections.length} sections failed` : `\nall ${sections.length} sections passed`);
process.exit(failed ? 1 : 0);

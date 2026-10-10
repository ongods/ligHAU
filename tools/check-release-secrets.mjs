// Verify current private credentials never appear in generated browser assets.
// Reports credential names only, never credential values.
import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
const env = readFileSync(new URL('../.env', import.meta.url), 'utf8');
const keys = ['GEMINI_API_KEY', 'MAPTILER_SERVICE_TOKEN', 'DATABASE_URL', 'DATABASE_MIGRATION_URL'].map((name) => {
  const line = env.split(/\r?\n/).find((item) => item.trimStart().startsWith(`${name}=`));
  let value = line?.trimStart().slice(name.length + 1).trim();
  if (value && ['"', "'"].includes(value[0]) && value.at(-1) === value[0]) value = value.slice(1, -1);
  return { name, value };
}).filter((item) => item.value);
let files = 0;
const leaks = new Set();
function walk(directory) {
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    const file = join(directory, entry.name);
    if (entry.isDirectory()) walk(file);
    else {
      files++;
      const bytes = readFileSync(file);
      for (const key of keys) if (bytes.includes(Buffer.from(key.value))) leaks.add(key.name);
    }
  }
}
walk(fileURLToPath(new URL('../build/web/', import.meta.url)));
console.log(JSON.stringify({ releaseFilesScanned: files, privateKeysChecked: keys.map((item) => item.name), privateKeyLeaks: [...leaks] }));
if (leaks.size || !keys.some((item) => item.name === 'GEMINI_API_KEY')) process.exitCode = 1;

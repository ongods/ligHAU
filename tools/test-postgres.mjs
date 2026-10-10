// Owns one temporary test container; never uses DATABASE_URL or app port 8787.
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { randomUUID } from 'node:crypto';
import pg from 'pg';
const exec = promisify(execFile);
const name = `lighau-pg-test-${randomUUID()}`;
let container;
try {
  container = (await exec('docker', ['run', '--detach', '--rm', '--name', name,
    '--label', `lighau.test=${name}`, '--env', 'POSTGRES_PASSWORD=lighau-test-only-password',
    '--publish', '127.0.0.1::5432', 'postgres:17-bookworm'], { timeout: 180000 })).stdout.trim();
  const mapping = (await exec('docker', ['port', container, '5432/tcp'])).stdout.trim();
  const port = Number(mapping.split(':').at(-1));
  if (!Number.isInteger(port)) throw new Error('Test port could not be resolved.');
  const url = `postgresql://postgres:lighau-test-only-password@127.0.0.1:${port}/postgres`;
  const deadline = Date.now() + 60000;
  while (true) {
    const client = new pg.Client({ connectionString: url, connectionTimeoutMillis: 1000 });
    try { await client.connect(); await client.query('SELECT 1'); break; }
    catch (error) { if (Date.now() >= deadline) throw error; await new Promise(resolve => setTimeout(resolve, 500)); }
    finally { await client.end().catch(() => {}); }
  }
  const child = await import('node:child_process');
  const result = await new Promise((resolve, reject) => {
    const tests = child.spawn(process.execPath, ['--test', 'server/postgres.test.mjs'], {
      stdio: 'inherit', env: { ...process.env, TEST_DATABASE_URL: url, PG_TEST_ALLOW_RESET: 'true' },
    });
    tests.on('error', reject); tests.on('exit', resolve);
  });
  process.exitCode = result ?? 1;
} catch { console.error('Isolated Postgres tests could not finish. Check Docker and the test output.'); process.exitCode = 1; }
finally {
  if (container) {
    const label = (await exec('docker', ['inspect', '--format', '{{index .Config.Labels "lighau.test"}}', container])).stdout.trim();
    if (label !== name) throw new Error('Refusing to remove a container not owned by this test run.');
    await exec('docker', ['rm', '--force', container]);
  }
}

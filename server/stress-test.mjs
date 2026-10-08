// Isolated load test: no real provider calls or changes to the live catalog.
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { performance, monitorEventLoopDelay } from 'node:perf_hooks';
import { once } from 'node:events';
import { createChatServer } from './chat-server.mjs';
import { FacilityStore } from './facility-store.mjs';
import { SqliteUsageStore } from './sqlite-usage.mjs';
import { AppDatabase } from './database.mjs';
import { AdminAuth } from './admin-auth.mjs';
import { ChatLimits } from './chat-limits.mjs';
import { loadCampusData } from './campus-data.mjs';

const directory = mkdtempSync(join(tmpdir(), 'lighau-stress-'));
const catalog = loadCampusData();
const file = join(directory, 'campus.sqlite');
const database = new AppDatabase(file);
const store = new FacilityStore({ catalog, database });
const adminAuth = new AdminAuth(database);
await adminAuth.createAccount('stress-admin', 'isolated-stress-password');
const session = await adminAuth.login('stress-admin', 'isolated-stress-password', 'stress-client');
let providerActive = 0;
let providerPeak = 0;
let providerCalls = 0;
const fakeProvider = async () => {
  providerCalls++;
  providerPeak = Math.max(providerPeak, ++providerActive);
  await new Promise((resolve) => setTimeout(resolve, 250));
  providerActive--;
  return Response.json({ candidates: [{ finishReason: 'STOP', content: { parts: [{ text: JSON.stringify({ answer: 'Simulated campus answer.', facilityNames: [] }) }] } }], usageMetadata: { promptTokenCount: 10, candidatesTokenCount: 5, totalTokenCount: 15 } });
};
const server = createChatServer({ apiKey: 'stress-test-only', model: 'test-model', fetchImpl: fakeProvider, catalog,
  database, auth: adminAuth, limiter: new ChatLimits(database, { perClient: 1000, rpm: 100, queue: 0 }),
  facilityStore: store, usage: new SqliteUsageStore(database), mapToken: '' });
const eventLoop = monitorEventLoopDelay({ resolution: 10 });
const results = [];
const auth = { Authorization: `Bearer ${session.token}`, 'Content-Type': 'application/json' };
function persisted() {
  const reloaded = new AppDatabase(file);
  try { return new FacilityStore({ catalog: [], database: reloaded }).all(); }
  finally { reloaded.close(); }
}
const chatBody = JSON.stringify({ messages: [{ role: 'user', text: 'Where is the library?' }] });
let base;
let httpRequests = 0;
async function request(path, options = {}) {
  httpRequests++;
  const response = await fetch(`${base}${path}`, { ...options, signal: AbortSignal.timeout(10000) });
  const body = await response.json();
  return { status: response.status, body };
}
async function scenario(name, count, concurrency, operation, seconds = 0) {
  let next = 0;
  const durations = [];
  const statuses = {};
  const start = performance.now();
  const deadline = seconds ? start + seconds * 1000 : Infinity;
  await Promise.all(Array.from({ length: concurrency }, async () => {
    while (next < count && performance.now() < deadline) {
      const index = next++;
      const at = performance.now();
      const response = await operation(index);
      durations.push(performance.now() - at);
      statuses[response.status] = (statuses[response.status] || 0) + 1;
    }
  }));
  durations.sort((a, b) => a - b);
  const elapsed = performance.now() - start;
  const percentile = (p) => Number(durations[Math.min(durations.length - 1, Math.ceil(durations.length * p) - 1)].toFixed(1));
  const result = { name, requests: durations.length, concurrency, statuses, durationMs: Number(elapsed.toFixed(1)), requestsPerSecond: Number((durations.length * 1000 / elapsed).toFixed(1)), p50Ms: percentile(.5), p95Ms: percentile(.95), p99Ms: percentile(.99) };
  results.push(result);
  console.log(JSON.stringify(result));
  return result;
}
try {
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  base = `http://127.0.0.1:${server.address().port}`;
  eventLoop.enable();
  const reads = await scenario('catalog reads', 2000, 50, async () => {
    const response = await request('/api/facilities');
    assert.equal(response.status, 200);
    assert.equal(response.body.facilities.length, catalog.length);
    return response;
  });
  assert.equal(reads.statuses[200], 2000);
  assert.ok(reads.p95Ms < 1000, 'Local catalog p95 must be below 1 second.');
  await scenario('persistent catalog creates', 200, 10, async (index) => {
    const response = await request('/api/admin/facilities', { method: 'POST', headers: auth,
      body: JSON.stringify({ ...catalog[0], name: `Stress place ${index}` }) });
    assert.equal(response.status, 200);
    return response;
  });
  assert.equal(persisted().length, catalog.length + 200);
  const added = store.all().filter((item) => item.name.startsWith('Stress place '));
  await scenario('mixed edits deletes and reads', 400, 20, async (index) => {
    const record = added[index % 200];
    const current = store.all().find((item) => item.id === record.id);
    const response = index >= 200
      ? await request(`/api/admin/facilities/${record.id}`, { method: 'DELETE', headers: { ...auth, 'If-Match': `"${current.version}"` } })
      : await request(`/api/admin/facilities/${record.id}`, { method: 'PUT', headers: auth, body: JSON.stringify({ ...current, description: `Stress update ${index}` }) });
    assert.equal(response.status, 200);
    assert.equal((await request('/api/facilities')).status, 200);
    return response;
  });
  assert.equal(persisted().length, catalog.length);
  await scenario('unauthorized writes', 100, 20, async () => {
    const response = await request('/api/admin/facilities', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}' });
    assert.equal(response.status, 401);
    return response;
  });
  const burst = await scenario('chat burst with 250ms simulated provider', 100, 100, () => request('/api/chat', { method: 'POST', headers: auth, body: chatBody }));
  // Arrival times can span several provider completions on a loaded machine.
  // Verify the concurrent-provider invariant rather than an exact success count.
  assert.ok(burst.statuses[200] >= 2 && burst.statuses[200] <= 30);
  assert.equal(burst.statuses[429], 100 - burst.statuses[200]);
  assert.equal(providerPeak, 2);
  await scenario('chat fills remaining global allowance', 30 - providerCalls, 1, async () => {
    const response = await request('/api/chat', { method: 'POST', headers: auth, body: chatBody });
    assert.equal(response.status, 200);
    return response;
  });
  await scenario('chat after global allowance exhausted', 100, 20, async () => {
    const response = await request('/api/chat', { method: 'POST', headers: auth, body: chatBody });
    assert.equal(response.status, 429);
    return response;
  });
  assert.equal(providerCalls, 30);
  const usage = await request('/api/admin/usage', { headers: auth });
  assert.equal(usage.body.gemini.total.successes, 30);
  assert.equal(usage.body.gemini.appLimit.active, 0);
  assert.equal((await request('/health')).status, 200);
  const soakArg = process.argv.find((item) => item.startsWith('--soak-seconds='));
  if (soakArg) {
    const seconds = Number(soakArg.split('=')[1]);
    assert.ok(Number.isInteger(seconds) && seconds >= 10 && seconds <= 600, 'Soak duration must be 10–600 seconds.');
    const soak = await scenario('sustained catalog reads', Infinity, 10, async () => {
      const result = await request('/api/facilities');
      assert.equal(result.status, 200);
      return result;
    }, seconds);
    assert.ok(soak.p95Ms < 1000, 'Sustained local catalog p95 must be below 1 second.');
  }
  eventLoop.disable();
  const report = { completedAt: new Date().toISOString(), node: process.version, platform: process.platform,
    scope: 'Single local Node process; isolated SQLite catalog; simulated Gemini. Stress-only per-client/RPM overrides and zero queue isolate the global safety limit; production defaults are tested separately. No browser/map or real provider quota testing.',
    passed: true, httpRequests, results, providerCalls, providerPeak, persistedCatalogVerified: true,
    eventLoopP99Ms: Number((eventLoop.percentile(99) / 1e6).toFixed(1)), peakObservedRssMb: Number((process.resourceUsage().maxRSS / 1024).toFixed(1)) };
  writeFileSync(new URL('../docs/stress-results.json', import.meta.url), JSON.stringify(report, null, 2));
  console.log('PASS: isolated stress test; report saved to docs/stress-results.json');
} catch (error) {
  writeFileSync(new URL('../docs/stress-results.json', import.meta.url), JSON.stringify({ completedAt: new Date().toISOString(), passed: false,
    scope: 'Isolated SQLite load test; simulated provider; no live catalog changes.', httpRequests, results, failure: error.message }, null, 2));
  throw error;
} finally {
  eventLoop.disable();
  server.closeAllConnections();
  await new Promise((resolve) => server.close(resolve));
  database.close();
  rmSync(directory, { recursive: true, force: true });
}

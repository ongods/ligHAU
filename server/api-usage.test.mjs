import test from 'node:test';
import { testAdmin } from './test-support.mjs';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { mkdtempSync, unlinkSync, rmdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { UsageStore, mapTilerUsage, pacificDay, quota } from './api-usage.mjs';
import { createChatServer } from './chat-server.mjs';

test('counts survive restart, isolate models, expire minute usage and reset on Pacific midnight', (t) => {
  const dir = mkdtempSync(join(tmpdir(), 'lighau-usage-'));
  const file = join(dir, 'counts.json');
  t.after(() => { unlinkSync(file); rmdirSync(dir); });
  let now = Date.parse('2026-10-06T06:59:30Z');
  const usage = new UsageStore({ file, now: () => now });
  const event = usage.start('gemini-test');
  usage.finish(event, { success: true, status: 200, metadata: { promptTokenCount: 12, candidatesTokenCount: 8, totalTokenCount: 25 } });
  assert.equal(usage.snapshot('gemini-test').today.totalTokens, 25); // includes thinking, not input+output.
  assert.equal(usage.snapshot('gemini-test').minute.inputTokens, 12);
  assert.equal(usage.snapshot('other-model').total.requests, 0);
  const reloaded = new UsageStore({ file, now: () => now });
  assert.equal(reloaded.snapshot('gemini-test').total.requests, 1);
  assert.equal(reloaded.snapshot('gemini-test').persistent, true);
  now += 61000;
  assert.equal(usage.snapshot('gemini-test').today.requests, 0);
  assert.equal(usage.snapshot('gemini-test').minute.requests, 0);
  assert.equal(usage.snapshot('gemini-test').total.requests, 1);
  assert.equal(pacificDay(Date.parse('2026-01-06T07:59:59Z')), '2026-01-05');
});

test('quota unknown, zero and invalid reference values are distinguished', () => {
  assert.equal(quota(''), null);
  assert.equal(quota('invalid'), null);
  assert.equal(quota('-1'), null);
  assert.equal(quota('0'), 0);
  assert.equal(quota('100'), 100);
});

test('MapTiler uses a private service token, aggregates account data, and sanitizes failures', async () => {
  const data = await mapTilerUsage({ token: 'private-token', requestQuota: '1000', fetchImpl: async (url, options) => {
    assert.equal(options.headers.Authorization, 'Token private-token');
    assert.ok(!url.includes('private-token'));
    return Response.json({ since: '2026-10-01', until: '2026-10-06', datasets: [
      { group_id: 'request', data: [{ date: '2026-10-05', value: 10 }], estimated_data: { date: '2026-10-06', value: 5 } },
      { group_id: 'request', data: [{ date: '2026-10-05', value: 3 }] },
      { group_id: 'session', data: [{ date: '2026-10-06', value: 2 }], estimated_data: { date: '2026-10-06', value: 2 } },
    ] });
  } });
  assert.equal(data.requests, 18);
  assert.equal(data.sessions, 2);
  assert.equal(data.estimated, true);
  assert.equal(data.limits.requests, 1000);
  assert.equal(data.limits.sessions, null);
  assert.equal((await mapTilerUsage({})).status, 'not_configured');
  const failed = await mapTilerUsage({ token: 'private-token', fetchImpl: async () => { throw new Error('private-token'); } });
  assert.equal(failed.status, 'unavailable');
  assert.ok(!JSON.stringify(failed).includes('private-token'));
});

test('usage endpoint requires admin auth and reports only provider calls including malformed answers and 429s', async (t) => {
  const admin = await testAdmin();
  let calls = 0;
  const server = createChatServer({ ...admin, apiKey: 'private-gemini-key', mapToken: '', geminiLimits: { rpm: '10', tpm: '', rpd: '0' }, fetchImpl: async () => {
    calls++;
    if (calls === 3) return new Response('private-gemini-key', { status: 429 });
    return Response.json({ usageMetadata: { promptTokenCount: 100, candidatesTokenCount: 20, totalTokenCount: 125 },
      candidates: [{ finishReason: 'STOP', content: { parts: [{ text: JSON.stringify(calls === 1 ? { answer: 'Campus answer', facilityNames: [] } : { invalid: true }) }] } }] });
  } });
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  t.after(() => { server.closeAllConnections(); server.close(); });
  const base = `http://127.0.0.1:${server.address().port}`;
  const headers = admin.headers;
  assert.equal((await fetch(`${base}/api/admin/usage`)).status, 401);
  assert.equal((await fetch(`${base}/api/admin/usage`, { headers: { Authorization: 'Basic wrong' } })).status, 401);
  assert.equal(calls, 0);
  const preflight = await fetch(`${base}/api/admin/usage`, { method: 'OPTIONS', headers: { Origin: 'http://localhost:8080' } });
  assert.match(preflight.headers.get('access-control-allow-headers'), /Authorization/);
  await fetch(`${base}/api/chat`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}' });
  for (const status of [200, 502, 429]) {
    const response = await fetch(`${base}/api/chat`, { method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ messages: [{ role: 'user', text: 'Campus?' }] }) });
    assert.equal(response.status, status);
  }
  const result = await (await fetch(`${base}/api/admin/usage`, { headers })).json();
  assert.equal(result.gemini.today.requests, 3);
  assert.equal(result.gemini.today.successes, 1);
  assert.equal(result.gemini.today.failures, 2);
  assert.equal(result.gemini.today.rateLimited, 1);
  assert.equal(result.gemini.today.totalTokens, 250);
  assert.equal(result.gemini.today.missingTokenReports, 1);
  assert.equal(result.gemini.limits.rpm, 10);
  assert.equal(result.gemini.limits.rpd, 0);
  assert.equal(result.gemini.limits.tpm, null);
  assert.equal(result.maptiler.status, 'not_configured');
  assert.ok(!JSON.stringify(result).includes('private-gemini-key'));
});

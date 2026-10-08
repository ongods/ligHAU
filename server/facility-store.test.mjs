import test from 'node:test';
import { testAdmin } from './test-support.mjs';
import assert from 'node:assert/strict';
import { mkdtempSync, unlinkSync, rmdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { once } from 'node:events';
import { loadCampusData } from './campus-data.mjs';
import { FacilityStore } from './facility-store.mjs';
import { createChatServer } from './chat-server.mjs';

test('catalog persists edits, preserves map identity across renames and supports add/delete', (t) => {
  const dir = mkdtempSync(join(tmpdir(), 'lighau-catalog-'));
  const file = join(dir, 'catalog.json');
  t.after(() => { unlinkSync(file); rmdirSync(dir); });
  const store = new FacilityStore({ catalog: loadCampusData(), file });
  const original = store.all().find((f) => f.hasMapLocation);
  const updated = { ...original, name: 'Renamed campus place', description: 'Updated description', hours: '8:00 AM – 6:00 PM', facilities: ['New service'] };
  store.upsert(original.id, updated);
  const reloaded = new FacilityStore({ catalog: [], file });
  const saved = reloaded.all().find((f) => f.id === original.id);
  assert.equal(saved.name, updated.name);
  assert.equal(saved.description, updated.description);
  assert.equal(saved.sourceName, original.name);
  assert.equal(saved.hasMapLocation, true);
  assert.throws(() => reloaded.upsert(null, saved), { status: 409 });
  reloaded.upsert(null, { ...saved, name: 'New building' });
  const added = reloaded.all().find((f) => f.name === 'New building');
  assert.equal(added.hasMapLocation, false);
  reloaded.upsert(added.id, { ...added, latitude: 15.1325, longitude: 120.5901 });
  const pinned = new FacilityStore({ catalog: [], file }).all().find((f) => f.id === added.id);
  assert.equal(pinned.latitude, 15.1325);
  assert.equal(pinned.longitude, 120.5901);
  assert.equal(pinned.hasMapLocation, true);
  reloaded.upsert(added.id, { ...pinned, latitude: null, longitude: null });
  assert.equal(reloaded.all().find((f) => f.id === added.id).hasMapLocation, false);
  reloaded.remove(added.id);
  assert.ok(!new FacilityStore({ catalog: [], file }).all().some((f) => f.id === added.id));
});

test('coordinate validation rejects incomplete, nonnumeric and out-of-range points', () => {
  const store = new FacilityStore({ catalog: loadCampusData() });
  const original = store.all()[0];
  for (const point of [
    { latitude: 15.1 }, { longitude: 120.5 },
    { latitude: 91, longitude: 120.5 }, { latitude: 15.1, longitude: -181 },
    { latitude: '15.1', longitude: 120.5 }, { latitude: NaN, longitude: 120.5 },
  ]) assert.throws(() => store.upsert(original.id, { ...original, ...point }), { status: 400 });
  const mapped = store.all().find((f) => f.hasMapLocation);
  store.upsert(mapped.id, { ...mapped, latitude: 15.1325, longitude: 120.5901 });
  store.upsert(mapped.id, { ...mapped, latitude: null, longitude: null });
  assert.equal(store.all().find((f) => f.id === mapped.id).hasMapLocation, true);
});

test('admin edits appear in public catalog and Gemini prompt; writes require credentials', async (t) => {
  const admin = await testAdmin();
  let prompt;
  const server = createChatServer({ ...admin, apiKey: 'test', fetchImpl: async (_, options) => {
    prompt = JSON.parse(options.body).systemInstruction.parts[0].text;
    return Response.json({ candidates: [{ finishReason: 'STOP', content: { parts: [{ text: JSON.stringify({ answer: 'Updated campus fact', facilityNames: [] }) }] } }] });
  } });
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  t.after(() => { server.closeAllConnections(); server.close(); });
  const base = `http://127.0.0.1:${server.address().port}`;
  const original = (await (await fetch(`${base}/api/facilities`)).json()).facilities[0];
  const url = `${base}/api/admin/facilities/${original.id}`;
  assert.equal((await fetch(url, { method: 'DELETE' })).status, 401);
  const headers = admin.headers;
  const result = await fetch(url, { method: 'PUT', headers, body: JSON.stringify({ ...original, description: 'Shared catalog test description' }) });
  assert.equal(result.status, 200);
  const catalog = (await (await fetch(`${base}/api/facilities`)).json()).facilities;
  assert.equal(catalog[0].description, 'Shared catalog test description');
  await fetch(`${base}/api/chat`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ messages: [{ role: 'user', text: 'Campus?' }] }) });
  assert.ok(prompt.includes('Shared catalog test description'));
  assert.equal((await fetch(url, { method: 'PUT', headers, body: JSON.stringify({ ...original, name: '' }) })).status, 400);
});

import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';
import { once } from 'node:events';
import { AppDatabase } from './database.mjs';
import { AdminAuth } from './admin-auth.mjs';
import { ChatLimits } from './chat-limits.mjs';
import { FacilityStore } from './facility-store.mjs';
import { SqliteUsageStore } from './sqlite-usage.mjs';
import { loadCampusData } from './campus-data.mjs';
import { createChatServer } from './chat-server.mjs';

test('accounts use salted hashes; sessions expire, revoke and require admin roles; login throttles', async () => {
  const db = new AppDatabase();
  let now = Date.now();
  const auth = new AdminAuth(db, { now: () => now, sessionMs: 1000 });
  await auth.createAccount('campus-admin', 'a-private-test-password');
  const row = db.sql.prepare('SELECT * FROM accounts').get();
  assert.ok(!row.hash.includes('a-private-test-password'));
  await assert.rejects(auth.login('admin', 'admin', 'unknown'), { status: 401 });
  const session = await auth.login('campus-admin', 'a-private-test-password', 'good-client');
  assert.equal(auth.require(`Bearer ${session.token}`), 'campus-admin');
  assert.notEqual(db.sql.prepare('SELECT hash FROM sessions').get().hash, session.token);
  now += 1001;
  assert.throws(() => auth.require(`Bearer ${session.token}`), { status: 401 });
  const second = await auth.login('campus-admin', 'a-private-test-password', 'good-client');
  auth.logout(`Bearer ${second.token}`);
  assert.throws(() => auth.require(`Bearer ${second.token}`), { status: 401 });
  for (let i = 0; i < 5; i++) await assert.rejects(auth.login('unknown-user', 'wrong', 'brute-client'), { status: 401 });
  await assert.rejects(auth.login('unknown-user', 'wrong', 'brute-client'), { status: 429 });
  const third = await auth.login('campus-admin', 'a-private-test-password', 'good-client');
  db.sql.prepare("UPDATE accounts SET role='viewer' WHERE username='campus-admin'").run();
  assert.throws(() => auth.require(`Bearer ${third.token}`), { status: 401 });
  assert.ok(!JSON.stringify(db.sql.prepare('SELECT * FROM audit').all()).includes('a-private-test-password'));
  db.close();
});

test('SQLite connections reject lost updates and commit catalog plus audit atomically', (t) => {
  const dir = mkdtempSync(join(tmpdir(), 'lighau-conflict-'));
  const a = new AppDatabase(join(dir, 'db.sqlite'));
  const b = new AppDatabase(join(dir, 'db.sqlite'));
  t.after(() => { a.close(); b.close(); rmSync(dir, { recursive: true }); });
  const first = new FacilityStore({ database: a, catalog: loadCampusData() });
  const second = new FacilityStore({ database: b, catalog: loadCampusData() });
  const original = first.all()[0];
  first.upsert(original.id, { ...original, description: 'First admin update' }, 'first-admin');
  assert.throws(() => second.upsert(original.id, { ...original, description: 'Stale overwrite' }, 'second-admin'), { status: 412 });
  assert.throws(() => second.remove(original.id, { version: original.version }), { status: 412 });
  assert.equal(second.all()[0].description, 'First admin update');
  const before = first.all();
  const audit = a.audit.bind(a);
  a.audit = () => { throw new Error('Simulated audit failure'); };
  assert.throws(() => first.upsert(original.id, { ...first.all()[0], description: 'Should roll back' }, 'first-admin'));
  a.audit = audit;
  assert.deepEqual(first.all(), before);
  assert.equal(a.sql.prepare('SELECT count(*) AS n FROM audit').get().n, 1);
});

test('backup and restore retain catalog, audit and usage, while revoking restored sessions', async (t) => {
  const dir = mkdtempSync(join(tmpdir(), 'lighau-recovery-'));
  const file = join(dir, 'db.sqlite');
  const db = new AppDatabase(file);
  const store = new FacilityStore({ database: db, catalog: loadCampusData() });
  const original = store.all()[0];
  store.upsert(original.id, { ...original, description: 'Recover this campus information' }, 'test-admin');
  const usage = new SqliteUsageStore(db);
  const event = usage.start('test-model');
  usage.finish(event, { success: true, status: 200, metadata: { totalTokenCount: 10 } });
  const auth = new AdminAuth(db);
  await auth.createAccount('recovery-admin', 'private-recovery-password');
  const session = await auth.login('recovery-admin', 'private-recovery-password', 'test');
  const command = fileURLToPath(new URL('./backup.mjs', import.meta.url));
  const backup = join(dir, 'backup.sqlite');
  execFileSync(process.execPath, [command, 'backup', backup], { env: { ...process.env, CAMPUS_DB_PATH: file } });
  const restoredFile = join(dir, 'restored.sqlite');
  execFileSync(process.execPath, [command, 'restore', backup, restoredFile]);
  const restored = new AppDatabase(restoredFile);
  t.after(() => { restored.close(); db.close(); rmSync(dir, { recursive: true }); });
  assert.ok(restored.integrity());
  assert.equal(new FacilityStore({ database: restored, catalog: [] }).all()[0].description, 'Recover this campus information');
  assert.equal(new SqliteUsageStore(restored).snapshot('test-model').total.requests, 1);
  assert.throws(() => new AdminAuth(restored).require(`Bearer ${session.token}`), { status: 401 });
  assert.ok(restored.sql.prepare("SELECT * FROM audit WHERE operation='database-restored'").get());
  assert.ok(!readFileSync(backup).includes(Buffer.from('private-recovery-password')));
});

test('per-client and global limits plus provider concurrency are shared between connections', async (t) => {
  const dir = mkdtempSync(join(tmpdir(), 'lighau-limits-'));
  const a = new AppDatabase(join(dir, 'db.sqlite'));
  const b = new AppDatabase(join(dir, 'db.sqlite'));
  t.after(() => { a.close(); b.close(); rmSync(dir, { recursive: true }); });
  const options = { perClient: 1, global: 3, daily: 3, rpm: 3, concurrency: 1, waitMs: 500 };
  const first = new ChatLimits(a, options), second = new ChatLimits(b, options);
  const lease = await first.acquire('client-a');
  await assert.rejects(second.acquire('client-a'), { status: 429 });
  const pending = second.acquire('client-b');
  assert.equal(second.snapshot().active, 1);
  first.release(lease);
  second.release(await pending);
  first.release(await first.acquire('client-c'));
  await assert.rejects(second.acquire('client-d'), { status: 429 });
  assert.equal(second.snapshot().used, 3);
});

test('production rejects plaintext and ignores spoofed proxy headers', async (t) => {
  const server = createChatServer({ production: true });
  server.listen(0, '127.0.0.1'); await once(server, 'listening');
  t.after(() => { server.closeAllConnections(); server.close(); });
  const response = await fetch(`http://127.0.0.1:${server.address().port}/api/admin/login`, {
    method: 'POST', headers: { 'Content-Type': 'application/json', 'X-Forwarded-Proto': 'https' }, body: '{}',
  });
  assert.equal(response.status, 403);
});

test('HTTP login, versioned CRUD, chat map actions and usage survive a backend restart', async (t) => {
  const dir = mkdtempSync(join(tmpdir(), 'lighau-http-restart-'));
  const file = join(dir, 'db.sqlite');
  let db = new AppDatabase(file);
  const auth = new AdminAuth(db);
  await auth.createAccount('http-admin', 'private-http-password');
  let server;
  const start = async () => {
    const store = new FacilityStore({ database: db, catalog: loadCampusData() });
    server = createChatServer({ database: db, auth: new AdminAuth(db), facilityStore: store, usage: new SqliteUsageStore(db), apiKey: 'test-key', mapToken: '',
      fetchImpl: async () => Response.json({ candidates: [{ finishReason: 'STOP', content: { parts: [{ text: JSON.stringify({ answer: 'Find the research center on the map.', facilityNames: ['Restart research center'] }) }] } }] }) });
    server.listen(0, '127.0.0.1'); await once(server, 'listening');
    return `http://127.0.0.1:${server.address().port}`;
  };
  const stop = async () => { server.closeAllConnections(); await new Promise((resolve) => server.close(resolve)); db.close(); };
  let base = await start();
  t.after(async () => { await stop(); rmSync(dir, { recursive: true }); });
  const login = await fetch(`${base}/api/admin/login`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ username: 'http-admin', password: 'private-http-password' }) });
  assert.equal(login.status, 200);
  const session = await login.json();
  const headers = { Authorization: `Bearer ${session.token}`, 'Content-Type': 'application/json' };
  const post = await fetch(`${base}/api/admin/facilities`, { method: 'POST', headers, body: JSON.stringify({ ...loadCampusData()[0], name: 'Restart research center', latitude: 15.1325, longitude: 120.5901 }) });
  assert.equal(post.status, 200);
  const place = (await post.json()).facilities.find((f) => f.name === 'Restart research center');
  const chat = await fetch(`${base}/api/chat`, { method: 'POST', headers, body: JSON.stringify({ messages: [{ role: 'user', text: 'Where is the research center?' }] }) });
  assert.deepEqual((await chat.json()).mapFacilityNames, [place.name]);
  await stop(); db = new AppDatabase(file); base = await start();
  const catalog = await (await fetch(`${base}/api/facilities`)).json();
  assert.ok(catalog.facilities.some((f) => f.id === place.id && f.latitude === 15.1325));
  const edited = await fetch(`${base}/api/admin/facilities/${place.id}`, { method: 'PUT', headers, body: JSON.stringify({ ...place, description: 'Persisted update' }) });
  assert.equal(edited.status, 200);
  assert.equal((await fetch(`${base}/api/admin/facilities/${place.id}`, { method: 'PUT', headers, body: JSON.stringify(place) })).status, 412);
  const latest = (await edited.json()).facilities.find((f) => f.id === place.id);
  assert.equal((await fetch(`${base}/api/admin/facilities/${place.id}`, { method: 'DELETE', headers })).status, 428);
  assert.equal((await fetch(`${base}/api/admin/facilities/${place.id}`, { method: 'DELETE', headers: { ...headers, 'If-Match': `"${latest.version}"` } })).status, 200);
  const usage = await (await fetch(`${base}/api/admin/usage`, { headers })).json();
  assert.equal(usage.gemini.total.requests, 1);
  assert.equal(usage.gemini.appLimit.used, 1);
  assert.equal((await fetch(`${base}/api/admin/logout`, { method: 'POST', headers })).status, 200);
  assert.equal((await fetch(`${base}/api/admin/usage`, { headers })).status, 401);
});

test('bounded queue times out without exceeding leases and provider cooldown is shared', async () => {
  const db = new AppDatabase();
  const limiter = new ChatLimits(db, { perClient: 10, concurrency: 1, queue: 1, waitMs: 75 });
  const active = await limiter.acquire('first-client');
  const waiting = limiter.acquire('second-client');
  await assert.rejects(limiter.acquire('third-client'), { status: 429 });
  await assert.rejects(waiting, { status: 429 });
  assert.equal(limiter.snapshot().active, 1);
  assert.equal(limiter.snapshot().queued, 0);
  limiter.release(active);
  limiter.cooldown();
  await assert.rejects(new ChatLimits(db).acquire('fourth-client'), { status: 429 });
  db.close();
});

import { describe, test, before, beforeEach, after } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync, mkdtempSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { once } from 'node:events';
import pg from 'pg';
import { PostgresDatabase, postgresOptions } from './postgres-database.mjs';
import { PostgresFacilityStore, PostgresAdminAuth, PostgresUsageStore, PostgresChatLimits } from './postgres-services.mjs';
import { loadCampusData } from './campus-data.mjs';
import { createChatServer } from './chat-server.mjs';
import { openBackendStorage } from './backend-storage.mjs';
import { AppDatabase } from './database.mjs';
import { FacilityStore } from './facility-store.mjs';
import { AdminAuth } from './admin-auth.mjs';
import { SqliteUsageStore } from './sqlite-usage.mjs';
import { importSqlite, readSqliteImport } from './import-sqlite.mjs';

test('Postgres settings enforce TLS, validate limits, and never fall back to SQLite', async () => {
  const options = postgresOptions({}, 'postgresql://app:private@db.example.com/postgres?sslmode=no-verify');
  assert.equal(options.ssl.rejectUnauthorized, true);
  assert.equal(new URL(options.connectionString).searchParams.has('sslmode'), false);
  assert.throws(() => postgresOptions({ DATABASE_SSL: 'disable' }, 'postgresql://app:private@db.example.com/postgres'));
  assert.throws(() => postgresOptions({ NODE_ENV: 'production', DATABASE_SSL: 'disable' }, 'postgresql://app:private@127.0.0.1/postgres'));
  await assert.rejects(openBackendStorage({ env: { DATABASE_DRIVER: 'postgres', DATABASE_URL: '' } }), /valid private DATABASE_URL/);
});

describe('isolated real Postgres integration', { skip: !process.env.TEST_DATABASE_URL }, () => {
  let owner, database, database2, env;
  before(async () => {
    const url = new URL(process.env.TEST_DATABASE_URL);
    if (url.hostname !== '127.0.0.1' || process.env.PG_TEST_ALLOW_RESET !== 'true') throw new Error('Only an explicitly disposable loopback test database may be reset.');
    owner = new pg.Pool({ connectionString: url.toString(), max: 2 });
    await owner.query('DROP SCHEMA IF EXISTS lighau CASCADE');
    await owner.query('CREATE ROLE anon NOLOGIN; CREATE ROLE authenticated NOLOGIN');
    const migration = readdirSync(new URL('../supabase/migrations/', import.meta.url)).find(name => name.endsWith('_lighau_postgres.sql'));
    await owner.query(readFileSync(new URL(`../supabase/migrations/${migration}`, import.meta.url), 'utf8'));
    await owner.query("ALTER ROLE lighau_backend PASSWORD 'lighau-runtime-test-password'");
    url.username = 'lighau_backend'; url.password = 'lighau-runtime-test-password';
    env = { DATABASE_DRIVER: 'postgres', DATABASE_SSL: 'disable', DATABASE_URL: url.toString(), DATABASE_POOL_SIZE: '5' };
    database = await PostgresDatabase.connect({ env });
    database2 = await PostgresDatabase.connect({ env });
  });
  beforeEach(async () => {
    await owner.query('TRUNCATE lighau.facilities,lighau.accounts,lighau.sessions,lighau.audit,lighau.counters,lighau.leases,lighau.provider_events RESTART IDENTITY CASCADE');
    await owner.query("DELETE FROM lighau.settings WHERE key<>'schema_version'");
  });
  after(async () => { await database?.close(); await database2?.close(); await owner?.end(); });

  test('private schema permissions allow runtime work and protect browser roles and audit history', async () => {
    assert.equal((await owner.query("SELECT has_schema_privilege('anon','lighau','USAGE') AS permitted")).rows[0].permitted, false);
    assert.equal((await owner.query("SELECT has_schema_privilege('authenticated','lighau','USAGE') AS permitted")).rows[0].permitted, false);
    assert.equal((await owner.query("SELECT bool_and(relrowsecurity) AS enabled FROM pg_class WHERE relnamespace='lighau'::regnamespace AND relkind='r'")).rows[0].enabled, true);
    await database.audit('test', 'test', null, null);
    await assert.rejects(database.query('DELETE FROM lighau.audit'), { code: '42501' });
    await assert.rejects(database.query('CREATE TABLE lighau.forbidden(id integer)'), { code: '42501' });
    await assert.rejects(PostgresDatabase.connect({ env: { ...env, DATABASE_URL: process.env.TEST_DATABASE_URL } }), /restricted/);
  });

  test('catalog seed runs once and concurrent versions and audit rollback preserve data', async () => {
    const a = new PostgresFacilityStore(database), b = new PostgresFacilityStore(database2);
    await Promise.all([a.initialize(loadCampusData()), b.initialize(loadCampusData())]);
    const original = (await a.all())[0];
    assert.equal((await a.all()).length, 22);
    const outcomes = await Promise.allSettled([
      a.upsert(original.id, { ...original, description: 'first concurrent edit' }, 'a'),
      b.upsert(original.id, { ...original, description: 'second concurrent edit' }, 'b'),
    ]);
    assert.equal(outcomes.filter(result => result.status === 'fulfilled').length, 1);
    assert.equal(outcomes.find(result => result.status === 'rejected').reason.status, 412);
    await assert.rejects(a.remove(original.id), { status: 428 });
    await assert.rejects(a.remove(original.id, { version: original.version }), { status: 412 });
    await assert.rejects(a.upsert(null, { ...original, name: original.name.toUpperCase() }), { status: 409 });
    const latest = (await a.all())[0];
    const audit = database.audit;
    database.audit = async () => { throw new Error('test audit failure'); };
    await assert.rejects(a.upsert(latest.id, { ...latest, description: 'must roll back' }));
    database.audit = audit;
    assert.deepEqual((await a.all())[0], latest);
    await a.initialize(loadCampusData());
    assert.deepEqual((await a.all())[0], latest);
  });

  test('admin hashes, sessions, disable, expiry, logout and login throttles work asynchronously', async () => {
    let now = Date.now();
    const auth = new PostgresAdminAuth(database, { now: () => now, sessionMs: 1000 });
    await auth.createAccount('test-admin', 'private-admin-password');
    assert.ok(!(await database.query('SELECT hash FROM lighau.accounts')).rows[0].hash.includes('private-admin-password'));
    const session = await auth.login('test-admin', 'private-admin-password', 'first-ip');
    assert.equal(await auth.require(`Bearer ${session.token}`), 'test-admin');
    now += 1001;
    await assert.rejects(auth.require(`Bearer ${session.token}`), { status: 401 });
    const second = await auth.login('test-admin', 'private-admin-password', 'first-ip');
    await auth.logout(`Bearer ${second.token}`);
    await assert.rejects(auth.require(`Bearer ${second.token}`), { status: 401 });
    const third = await auth.login('test-admin', 'private-admin-password', 'first-ip');
    await auth.disable('test-admin');
    await assert.rejects(auth.require(`Bearer ${third.token}`), { status: 401 });
    for (let i = 0; i < 5; i++) await assert.rejects(auth.login('unknown-user', 'wrong', 'bad-ip'), { status: 401 });
    await assert.rejects(auth.login('unknown-user', 'wrong', 'bad-ip'), { status: 429 });
  });

  test('shared counters and provider leases cannot overspend with concurrent connections', async () => {
    const options = { perClient: 30, global: 2, daily: 2, rpm: 2, concurrency: 2, queue: 0 };
    const a = new PostgresChatLimits(database, options), b = new PostgresChatLimits(database2, options);
    const attempts = await Promise.allSettled(Array.from({ length: 12 }, (_, i) => (i % 2 ? a : b).acquire(`ip-${i}`)));
    const leases = attempts.filter(result => result.status === 'fulfilled').map(result => result.value);
    assert.equal(leases.length, 2);
    assert.equal((await a.snapshot()).used, 2);
    assert.equal((await a.snapshot()).active, 2);
    await Promise.all(leases.map(id => a.release(id)));
    await assert.rejects(b.acquire('other-ip'), { status: 429 });
    await a.cooldown(60);
    await assert.rejects(b.acquire('more-ip'), { status: 429 });
  });

  test('usage totals preserve simultaneous provider results and survive reopening pools', async () => {
    const a = new PostgresUsageStore(database), b = new PostgresUsageStore(database2);
    const events = await Promise.all([a.start('test-model'), b.start('test-model')]);
    await Promise.all([a.finish(events[0], { success: true, metadata: { promptTokenCount: 3, candidatesTokenCount: 4, totalTokenCount: 7 } }),
      b.finish(events[1], { success: false, status: 429 })]);
    const reopened = await PostgresDatabase.connect({ env });
    try {
      const usage = await new PostgresUsageStore(reopened).snapshot('test-model');
      assert.equal(usage.total.requests, 2); assert.equal(usage.total.successes, 1);
      assert.equal(usage.total.rateLimited, 1); assert.equal(usage.total.totalTokens, 7);
      assert.equal(usage.minute.requests, 2); assert.equal(usage.minute.inputTokens, 3);
    } finally { await reopened.close(); }
  });

  test('consistent SQLite import preserves records and accounts, revokes sessions, and is one-time', async () => {
    const directory = mkdtempSync(join(tmpdir(), 'lighau-import-'));
    let sqlite;
    try {
      sqlite = new AppDatabase(join(directory, 'source.sqlite'));
      const store = new FacilityStore({ database: sqlite, catalog: loadCampusData() });
      const original = store.all()[0];
      store.upsert(original.id, { ...original, name: 'Imported building', latitude: 15.1, longitude: 120.5 }, 'import-admin');
      const auth = new AdminAuth(sqlite);
      await auth.createAccount('import-admin', 'private-import-password');
      await auth.login('import-admin', 'private-import-password', 'old-ip');
      const usage = new SqliteUsageStore(sqlite);
      const event = usage.start('test-model'); usage.finish(event, { success: true });
      sqlite.transaction(() => sqlite.counter('chat-global', 30, 600000));
      sqlite.backup(join(directory, 'backup.sqlite'));
      const source = readSqliteImport(join(directory, 'backup.sqlite'));
      await assert.rejects(importSqlite(database, { ...source, accounts: [...source.accounts, ...source.accounts] }), { code: '23505' });
      assert.equal((await database.query('SELECT count(*)::int AS n FROM lighau.facilities')).rows[0].n, 0);
      assert.equal(await database.get('sqlite_import'), undefined);
      const counts = await importSqlite(database, source);
      assert.equal(counts.facilities, 22); assert.equal(counts.revokedSessions, 1);
      assert.equal((await new PostgresFacilityStore(database).all())[0].name, 'Imported building');
      assert.equal((await database.query('SELECT count(*)::int AS n FROM lighau.sessions')).rows[0].n, 0);
      assert.equal((await new PostgresUsageStore(database).snapshot('test-model')).total.requests, 1);
      await new PostgresAdminAuth(database).login('import-admin', 'private-import-password', 'new-ip');
      await assert.rejects(importSqlite(database, source), /already initialized/);
      await new PostgresFacilityStore(database).initialize(loadCampusData());
      assert.equal((await new PostgresFacilityStore(database).all())[0].name, 'Imported building');
    } finally { sqlite?.close(); rmSync(directory, { recursive: true, force: true }); }
  });

  test('HTTP uses awaited Postgres auth, CRUD, live chatbot map actions and usage after restart', async () => {
    const storage = await openBackendStorage({ env });
    await storage.auth.createAccount('http-admin', 'private-http-password');
    const options = { ...storage, apiKey: 'test-key', mapToken: '',
      fetchImpl: async () => Response.json({ candidates: [{ finishReason: 'STOP', content: { parts: [{ text: JSON.stringify({ answer: 'New building', facilityNames: ['New test building'] }) }] } }] }) };
    let server = createChatServer(options);
    const start = async () => { server.listen(0, '127.0.0.1'); await once(server, 'listening'); return `http://127.0.0.1:${server.address().port}`; };
    const stop = async () => { server.closeAllConnections(); await new Promise(resolve => server.close(resolve)); };
    let base = await start();
    try {
      assert.equal((await fetch(`${base}/api/admin/usage`)).status, 401);
      const login = await (await fetch(`${base}/api/admin/login`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ username: 'http-admin', password: 'private-http-password' }) })).json();
      const headers = { 'Content-Type': 'application/json', Authorization: `Bearer ${login.token}` };
      const record = { ...loadCampusData()[0], name: 'New test building', latitude: 15.1, longitude: 120.5 };
      assert.equal((await fetch(`${base}/api/admin/facilities`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(record) })).status, 401);
      const saved = await (await fetch(`${base}/api/admin/facilities`, { method: 'POST', headers, body: JSON.stringify(record) })).json();
      const place = saved.facilities.find(record => record.name === 'New test building');
      assert.ok(place);
      const chat = await (await fetch(`${base}/api/chat`, { method: 'POST', headers, body: JSON.stringify({ messages: [{ role: 'user', text: 'Where is the new building?' }] }) })).json();
      assert.deepEqual(chat.mapFacilityNames, ['New test building']);
      await stop(); await storage.database.close();
      const restarted = await openBackendStorage({ env });
      server = createChatServer({ ...options, ...restarted }); base = await start();
      try {
        assert.ok((await (await fetch(`${base}/api/facilities`)).json()).facilities.some(record => record.id === place.id));
        assert.equal((await (await fetch(`${base}/api/admin/usage`, { headers })).json()).gemini.total.requests, 1);
        assert.equal((await fetch(`${base}/api/admin/logout`, { method: 'POST', headers })).status, 200);
        assert.equal((await fetch(`${base}/api/admin/usage`, { headers })).status, 401);
      } finally { await stop(); await restarted.database.close(); }
    } finally { if (server.listening) await stop(); await storage.database.close(); }
  });
});

import { DatabaseSync } from 'node:sqlite';
import { existsSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { PostgresDatabase } from './postgres-database.mjs';
import { validateFacility } from './facility-store.mjs';

export function readSqliteImport(file) {
  if (!file || !existsSync(file)) throw new Error('Provide an existing consistent SQLite backup.');
  const source = new DatabaseSync(file, { readOnly: true });
  try {
    if (source.prepare('PRAGMA integrity_check').get().integrity_check !== 'ok') throw new Error('SQLite backup failed its integrity check.');
    const settings = source.prepare('SELECT key,value FROM settings').all().map(row => ({ key: row.key, value: JSON.parse(row.value) }));
    const facilities = settings.find(row => row.key === 'catalog')?.value;
    if (!Array.isArray(facilities) || !facilities.length) throw new Error('SQLite backup has no campus catalog.');
    const ids = new Set(), names = new Set();
    for (const record of facilities) {
      validateFacility({ ...record, latitude: record.latitude ?? null, longitude: record.longitude ?? null });
      if (!/^[a-zA-Z0-9-]+$/.test(record.id) || !Number.isInteger(record.version) || record.version < 1 || ids.has(record.id) || names.has(record.name.toLowerCase())) throw new Error('SQLite catalog IDs, names or versions are invalid.');
      ids.add(record.id); names.add(record.name.toLowerCase());
    }
    return { settings, facilities, accounts: source.prepare('SELECT * FROM accounts').all(),
      audit: source.prepare('SELECT * FROM audit ORDER BY id').all(), counters: source.prepare('SELECT * FROM counters').all(),
      events: source.prepare('SELECT * FROM provider_events ORDER BY id').all(),
      oldSessions: source.prepare('SELECT count(*) AS n FROM sessions').get().n };
  } finally { source.close(); }
}

export async function importSqlite(database, source) {
  return database.transaction(async () => {
    await database.lock('catalog-initialize');
    if (await database.get('sqlite_import') || await database.get('catalog_initialized')) throw new Error('Target was already initialized or imported. Import only into an empty target.');
    for (const table of ['facilities', 'accounts', 'sessions', 'audit', 'counters', 'leases', 'provider_events']) {
      if ((await database.query(`SELECT count(*)::int AS n FROM lighau.${table}`)).rows[0].n) throw new Error('Target contains app data. Import cancelled without changing records.');
    }
    for (const { key, value } of source.settings) {
      if (!['catalog', 'schema_version', 'catalog_initialized', 'sqlite_import'].includes(key)) await database.set(key, value);
    }
    for (const record of source.facilities) await database.query('INSERT INTO lighau.facilities(id,name,version,record) VALUES ($1,$2,$3,$4::jsonb)', [record.id, record.name, record.version, JSON.stringify(record)]);
    for (const account of source.accounts) await database.query('INSERT INTO lighau.accounts(username,hash,role,disabled) VALUES ($1,$2,$3,$4)', [account.username, account.hash, account.role, Boolean(account.disabled)]);
    for (const row of source.audit) await database.query('INSERT INTO lighau.audit(at,actor,operation,facility_id,before_json,after_json) VALUES ($1,$2,$3,$4,$5::jsonb,$6::jsonb)', [row.at, row.actor, row.operation, row.facility_id, row.before_json, row.after_json]);
    for (const row of source.counters) await database.query('INSERT INTO lighau.counters(key,used,resets) VALUES ($1,$2,$3)', [row.key, row.used, row.resets]);
    for (const row of source.events) await database.query('INSERT INTO lighau.provider_events(model,at,input_tokens) VALUES ($1,$2,$3)', [row.model, row.at, row.input_tokens]);
    const counts = { facilities: source.facilities.length, accounts: source.accounts.length, audit: source.audit.length,
      counters: source.counters.length, events: source.events.length, revokedSessions: source.oldSessions };
    await database.set('catalog_initialized', true);
    await database.set('sqlite_import', { at: new Date().toISOString(), counts });
    await database.audit('sqlite-import-tool', 'sqlite-imported', null, null);
    return counts;
  });
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  let database;
  try {
    const source = readSqliteImport(process.argv[2]);
    if (!process.argv.includes('--apply')) {
      console.log(JSON.stringify({ dryRun: true, facilities: source.facilities.length, accounts: source.accounts.length,
        audit: source.audit.length, counters: source.counters.length, events: source.events.length, sessionsToRevoke: source.oldSessions }));
    } else {
      database = await PostgresDatabase.connect();
      console.log(JSON.stringify({ imported: await importSqlite(database, source) }));
    }
  } catch { console.error('Import stopped. Check the backup, TLS, schema and empty target. No credentials are printed.'); process.exitCode = 1; }
  finally { await database?.close(); }
}

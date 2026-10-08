import { DatabaseSync } from 'node:sqlite';
import { mkdirSync, chmodSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export const defaultDatabaseFile = () => resolve(process.env.CAMPUS_DB_PATH || fileURLToPath(new URL('./.local/campus.sqlite', import.meta.url)));
export class AppDatabase {
  constructor(file = ':memory:') {
    this.file = file;
    if (file !== ':memory:') mkdirSync(dirname(file), { recursive: true });
    this.sql = new DatabaseSync(file);
    this.sql.exec(`PRAGMA busy_timeout=5000; PRAGMA foreign_keys=ON; PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL;
      CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS accounts (username TEXT PRIMARY KEY, hash TEXT NOT NULL, role TEXT NOT NULL, disabled INTEGER NOT NULL DEFAULT 0);
      CREATE TABLE IF NOT EXISTS sessions (hash TEXT PRIMARY KEY, username TEXT NOT NULL REFERENCES accounts(username), expires INTEGER NOT NULL);
      CREATE TABLE IF NOT EXISTS counters (key TEXT PRIMARY KEY, used INTEGER NOT NULL, resets INTEGER NOT NULL);
      CREATE INDEX IF NOT EXISTS counter_expiry ON counters(resets);
      CREATE TABLE IF NOT EXISTS leases (id TEXT PRIMARY KEY, expires INTEGER NOT NULL);
      CREATE TABLE IF NOT EXISTS audit (id INTEGER PRIMARY KEY, at TEXT NOT NULL, actor TEXT NOT NULL, operation TEXT NOT NULL, facility_id TEXT, before_json TEXT, after_json TEXT);
      CREATE TABLE IF NOT EXISTS provider_events (id INTEGER PRIMARY KEY, model TEXT NOT NULL, at INTEGER NOT NULL, input_tokens INTEGER NOT NULL DEFAULT 0);
      CREATE INDEX IF NOT EXISTS provider_event_time ON provider_events(at);`);
    if (file !== ':memory:') chmodSync(file, 0o600);
  }
  transaction(operation) {
    this.sql.exec('BEGIN IMMEDIATE');
    try { const result = operation(); this.sql.exec('COMMIT'); return result; }
    catch (error) { this.sql.exec('ROLLBACK'); throw error; }
  }
  get(key) { const row = this.sql.prepare('SELECT value FROM settings WHERE key=?').get(key); return row ? JSON.parse(row.value) : undefined; }
  set(key, value) { this.sql.prepare('INSERT INTO settings VALUES (?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value').run(key, JSON.stringify(value)); }
  audit(actor, operation, before, after) {
    this.sql.prepare('INSERT INTO audit(at,actor,operation,facility_id,before_json,after_json) VALUES (?,?,?,?,?,?)').run(
      new Date().toISOString(), actor, operation, after?.id ?? before?.id ?? null,
      before ? JSON.stringify(before) : null, after ? JSON.stringify(after) : null);
  }
  // Called inside a transaction when several limits must be admitted atomically.
  counter(key, limit, windowMs, now = Date.now(), consume = true) {
    this.sql.prepare('DELETE FROM counters WHERE resets<=?').run(now);
    const row = this.sql.prepare('SELECT used,resets FROM counters WHERE key=?').get(key);
    if (row && row.used >= limit) return { allowed: false, retryAfter: Math.max(1, Math.ceil((row.resets - now) / 1000)) };
    if (consume) this.sql.prepare('INSERT INTO counters VALUES (?,?,?) ON CONFLICT(key) DO UPDATE SET used=used+1').run(key, 1, now + windowMs);
    return { allowed: true, used: (row?.used ?? 0) + (consume ? 1 : 0), resetsAt: row?.resets ?? now + windowMs };
  }
  backup(file) { this.sql.prepare('VACUUM INTO ?').run(resolve(file)); }
  integrity() { return this.sql.prepare('PRAGMA integrity_check').get().integrity_check === 'ok'; }
  close() { this.sql.close(); }
}

import pg from 'pg';
import { AsyncLocalStorage } from 'node:async_hooks';
import { readFileSync } from 'node:fs';

export function postgresOptions(env = process.env, connectionString = env.DATABASE_URL) {
  let url;
  try { url = new URL(connectionString); } catch { throw new Error('Set a valid private DATABASE_URL.'); }
  if (!['postgres:', 'postgresql:'].includes(url.protocol) || !url.hostname || !url.username || !url.pathname.slice(1)) {
    throw new Error('DATABASE_URL must contain a Postgres host, username and database.');
  }
  const local = ['localhost', '127.0.0.1', '[::1]'].includes(url.hostname);
  const disable = env.DATABASE_SSL === 'disable';
  if (disable && (!local || env.NODE_ENV === 'production')) throw new Error('DATABASE_SSL=disable is only allowed for local development databases.');
  // pg connection-string SSL parameters can override the explicit TLS object.
  for (const name of ['sslmode', 'sslcert', 'sslkey', 'sslrootcert']) url.searchParams.delete(name);
  const max = Number(env.DATABASE_POOL_SIZE || 5);
  if (!Number.isInteger(max) || max < 1 || max > 20) throw new Error('DATABASE_POOL_SIZE must be between 1 and 20.');
  return { connectionString: url.toString(), max, connectionTimeoutMillis: 5000,
    idleTimeoutMillis: 30000, statement_timeout: 5000, query_timeout: 7000,
    application_name: 'ligHAU', ssl: disable ? false : {
      rejectUnauthorized: true, ...(env.DATABASE_CA_FILE ? { ca: readFileSync(env.DATABASE_CA_FILE, 'utf8') } : {}),
    } };
}

export class PostgresDatabase {
  constructor(pool) { this.pool = pool; this.context = new AsyncLocalStorage(); this.driver = 'postgres'; }
  static async connect({ env = process.env, connectionString, maintenance = false } = {}) {
    const pool = new pg.Pool(postgresOptions(env, connectionString));
    pool.on('error', () => console.error('The database connection was interrupted.'));
    const db = new PostgresDatabase(pool);
    try {
      const { rows: [role] } = await db.query('SELECT rolsuper,rolbypassrls FROM pg_roles WHERE rolname=current_user');
      if (!maintenance && (role.rolsuper || role.rolbypassrls)) throw new Error('Use the restricted lighau_backend database role for DATABASE_URL.');
      if (!maintenance) {
        const version = await db.get('schema_version');
        if (version !== 1) throw new Error('Apply the reviewed ligHAU Postgres migration first.');
      }
      return db;
    } catch (error) { await pool.end(); throw error; }
  }
  query(text, values) { return (this.context.getStore() ?? this.pool).query(text, values); }
  async transaction(operation) {
    if (this.context.getStore()) return operation();
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      await client.query("SET LOCAL lock_timeout = '5s'");
      const result = await this.context.run(client, operation);
      await client.query('COMMIT');
      return result;
    } catch (error) { try { await client.query('ROLLBACK'); } catch {} throw error; }
    finally { client.release(); }
  }
  lock(key) {
    if (!this.context.getStore()) throw new Error('Database locks require a transaction.');
    return this.query('SELECT pg_advisory_xact_lock(hashtextextended($1,0))', [key]);
  }
  async get(key) { return (await this.query('SELECT value FROM lighau.settings WHERE key=$1', [key])).rows[0]?.value; }
  set(key, value) { return this.query('INSERT INTO lighau.settings(key,value) VALUES ($1,$2::jsonb) ON CONFLICT(key) DO UPDATE SET value=excluded.value', [key, JSON.stringify(value)]); }
  audit(actor, operation, before, after) {
    return this.query('INSERT INTO lighau.audit(at,actor,operation,facility_id,before_json,after_json) VALUES ($1,$2,$3,$4,$5::jsonb,$6::jsonb)',
      [new Date().toISOString(), actor, operation, after?.id ?? before?.id ?? null, before ? JSON.stringify(before) : null, after ? JSON.stringify(after) : null]);
  }
  async counter(key, limit, windowMs, now = Date.now(), consume = true) {
    await this.lock(`counter:${key}`);
    const { rows: [saved] } = await this.query('SELECT used,resets FROM lighau.counters WHERE key=$1', [key]);
    const row = saved && Number(saved.resets) > now ? saved : undefined;
    if (row && row.used >= limit) return { allowed: false, retryAfter: Math.max(1, Math.ceil((Number(row.resets) - now) / 1000)) };
    if (consume) await this.query('INSERT INTO lighau.counters(key,used,resets) VALUES ($1,$2,$3) ON CONFLICT(key) DO UPDATE SET used=excluded.used,resets=excluded.resets', [key, (row?.used ?? 0) + 1, Number(row?.resets ?? now + windowMs)]);
    return { allowed: true, used: (row?.used ?? 0) + (consume ? 1 : 0), resetsAt: Number(row?.resets ?? now + windowMs) };
  }
  close() { return this.closing ??= this.pool.end(); }
}

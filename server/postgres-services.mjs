import { randomBytes, randomUUID } from 'node:crypto';
import { timingSafeEqual } from 'node:crypto';
import { FacilityStore, CatalogError, validateFacility } from './facility-store.mjs';
import { AdminAuth, AuthError, derive, options, digest } from './admin-auth.mjs';
import { UsageStore, pacificDay } from './api-usage.mjs';
import { ChatLimits, LimitError } from './chat-limits.mjs';

export class PostgresFacilityStore {
  constructor(database) { this.db = database; }
  async initialize(catalog) {
    await this.db.transaction(async () => {
      await this.db.lock('catalog-initialize');
      if (await this.db.get('catalog_initialized')) return;
      if ((await this.db.query('SELECT count(*)::int AS n FROM lighau.facilities')).rows[0].n) throw new Error('Catalog exists without an initialization marker. Review the import first.');
      for (const record of new FacilityStore({ catalog }).all()) {
        await this.db.query('INSERT INTO lighau.facilities(id,name,version,record) VALUES ($1,$2,$3,$4::jsonb)', [record.id, record.name, record.version, JSON.stringify(record)]);
      }
      await this.db.set('catalog_initialized', true);
    });
  }
  async all() { return (await this.db.query('SELECT record FROM lighau.facilities ORDER BY position')).rows.map(row => row.record); }
  async upsert(id, value, actor = 'local') {
    try {
      return await this.db.transaction(async () => {
        const existing = id ? (await this.db.query('SELECT record FROM lighau.facilities WHERE id=$1 FOR UPDATE', [id])).rows[0]?.record : undefined;
        if (id && !existing) throw new CatalogError(404, 'This place no longer exists.');
        const fields = validateFacility(value);
        if (id) FacilityStore.prototype.checkVersion(existing, value.version);
        const record = { ...fields, id: existing?.id ?? randomUUID(), sourceName: existing?.sourceName ?? null,
          version: (existing?.version ?? 0) + 1, hasOriginalMapLocation: existing?.hasOriginalMapLocation ?? false,
          hasMapLocation: fields.latitude !== null || (existing?.hasOriginalMapLocation ?? false), hoursVerified: false };
        if (id) await this.db.query('UPDATE lighau.facilities SET name=$2,version=$3,record=$4::jsonb WHERE id=$1', [id, record.name, record.version, JSON.stringify(record)]);
        else await this.db.query('INSERT INTO lighau.facilities(id,name,version,record) VALUES ($1,$2,$3,$4::jsonb)', [record.id, record.name, record.version, JSON.stringify(record)]);
        await this.db.audit(actor, id ? 'facility-updated' : 'facility-created', existing, record);
        return this.all();
      });
    } catch (error) {
      if (error.code === '23505') throw new CatalogError(409, 'A place with this name already exists.');
      throw error;
    }
  }
  remove(id, { version, actor = 'local' } = {}) {
    return this.db.transaction(async () => {
      const existing = (await this.db.query('SELECT record FROM lighau.facilities WHERE id=$1 FOR UPDATE', [id])).rows[0]?.record;
      if (!existing) throw new CatalogError(404, 'This place no longer exists.');
      FacilityStore.prototype.checkVersion(existing, version);
      await this.db.query('DELETE FROM lighau.facilities WHERE id=$1', [id]);
      await this.db.audit(actor, 'facility-deleted', existing, null);
      return this.all();
    });
  }
}

export class PostgresAdminAuth extends AdminAuth {
  async createAccount(username, password, { reset = false } = {}) {
    username = username.trim().toLowerCase();
    if (!/^[a-z0-9][a-z0-9._@-]{2,99}$/.test(username)) throw new Error('Use a username of 3–100 letters, numbers, dots, underscores, @ or hyphens.');
    if (typeof password !== 'string' || password.length < 15 || password.length > 128) throw new Error('Use a password of 15–128 characters.');
    const salt = randomBytes(16).toString('hex');
    const hash = `${salt}:${(await derive(password, salt, 64, options)).toString('hex')}`;
    await this.db.transaction(async () => {
      await this.db.lock(`account:${username}`);
      const exists = (await this.db.query('SELECT username FROM lighau.accounts WHERE username=$1', [username])).rows[0];
      if (exists && !reset) throw new Error('That admin already exists. Use the reset command to change its password.');
      if (!exists && reset) throw new Error('That admin does not exist.');
      await this.db.query("INSERT INTO lighau.accounts(username,hash,role) VALUES ($1,$2,'admin') ON CONFLICT(username) DO UPDATE SET hash=excluded.hash,disabled=false", [username, hash]);
      await this.db.query('DELETE FROM lighau.sessions WHERE username=$1', [username]);
      await this.db.audit('local-admin-tool', reset ? 'admin-password-reset' : 'admin-created', null, { id: username });
    });
  }
  async login(username, password, client) {
    if (typeof username !== 'string' || typeof password !== 'string' || username.length > 100 || password.length > 128) throw new AuthError(401, 'Incorrect admin username or password.');
    username = username.trim().toLowerCase();
    const admission = await this.db.transaction(async () => {
      await this.db.lock('login-admission');
      for (const [key, limit] of [[`login-ip:${digest(client)}`, 10], [`login-user:${digest(username)}`, 5]]) {
        const result = await this.db.counter(key, limit, 900000, this.now(), false);
        if (!result.allowed) return result;
      }
      await this.db.counter(`login-ip:${digest(client)}`, 10, 900000, this.now());
      await this.db.counter(`login-user:${digest(username)}`, 5, 900000, this.now());
      return { allowed: true };
    });
    if (!admission.allowed) throw new AuthError(429, 'Too many sign-in attempts. Try again later.', admission.retryAfter);
    const account = (await this.db.query('SELECT * FROM lighau.accounts WHERE username=$1', [username])).rows[0];
    const [salt, expected] = (account?.hash ?? `${'0'.repeat(32)}:${'0'.repeat(128)}`).split(':');
    const actual = await derive(password, salt, 64, options);
    if (!account || account.disabled || account.role !== 'admin' || !timingSafeEqual(actual, Buffer.from(expected, 'hex'))) throw new AuthError(401, 'Incorrect admin username or password.');
    const token = randomBytes(32).toString('base64url');
    const expires = this.now() + this.sessionMs;
    await this.db.transaction(async () => {
      await this.db.query('DELETE FROM lighau.sessions WHERE expires<=$1', [this.now()]);
      const current = (await this.db.query('SELECT * FROM lighau.accounts WHERE username=$1 FOR UPDATE', [username])).rows[0];
      if (!current || current.disabled || current.role !== 'admin' || current.hash !== account.hash) throw new AuthError(401, 'Incorrect admin username or password.');
      await this.db.query('INSERT INTO lighau.sessions(hash,username,expires) VALUES ($1,$2,$3)', [digest(token), username, expires]);
      await this.db.query('DELETE FROM lighau.counters WHERE key=$1', [`login-user:${digest(username)}`]);
      await this.db.audit(username, 'admin-login', null, null);
    });
    return { token, expiresAt: new Date(expires).toISOString(), username, role: 'admin' };
  }
  async require(authorization) {
    const token = /^Bearer ([A-Za-z0-9_-]{43})$/.exec(authorization || '')?.[1];
    if (!token) throw new AuthError(401, 'Sign in as admin.');
    const session = (await this.db.query('SELECT s.username,s.expires,a.role,a.disabled FROM lighau.sessions s JOIN lighau.accounts a ON a.username=s.username WHERE s.hash=$1', [digest(token)])).rows[0];
    if (!session || Number(session.expires) <= this.now() || session.disabled || session.role !== 'admin') throw new AuthError(401, 'Your admin session has expired. Sign in again.');
    return session.username;
  }
  async logout(authorization) {
    const actor = await this.require(authorization);
    await this.db.transaction(async () => {
      await this.db.query('DELETE FROM lighau.sessions WHERE hash=$1', [digest(authorization.slice(7))]);
      await this.db.audit(actor, 'admin-logout', null, null);
    });
  }
  async list() { return (await this.db.query('SELECT username,role,disabled FROM lighau.accounts ORDER BY username')).rows; }
  async disable(username) {
    await this.db.transaction(async () => {
      const result = await this.db.query('UPDATE lighau.accounts SET disabled=true WHERE username=$1', [username.toLowerCase()]);
      if (!result.rowCount) throw new Error('That admin does not exist.');
      await this.db.query('DELETE FROM lighau.sessions WHERE username=$1', [username.toLowerCase()]);
      await this.db.audit('local-admin-tool', 'admin-disabled', null, { id: username.toLowerCase() });
    });
  }
}

export class PostgresUsageStore {
  constructor(database, { now = Date.now } = {}) { this.db = database; this.now = now; }
  async store() { const store = new UsageStore({ now: this.now }); store.state = await this.db.get('usage') ?? store.state; return store; }
  async start(model) {
    return this.db.transaction(async () => {
      await this.db.lock('usage');
      const store = await this.store();
      const event = store.start(model);
      await this.db.set('usage', store.state);
      event.id = (await this.db.query('INSERT INTO lighau.provider_events(model,at) VALUES ($1,$2) RETURNING id', [model, event.at])).rows[0].id;
      await this.db.query('DELETE FROM lighau.provider_events WHERE at<$1', [event.at - 86400000]);
      return event;
    });
  }
  async finish(event, result) {
    await this.db.transaction(async () => {
      await this.db.lock('usage');
      const store = await this.store();
      store.finish(event, result);
      await this.db.set('usage', store.state);
      await this.db.query('UPDATE lighau.provider_events SET input_tokens=$1 WHERE id=$2', [event.inputTokens, event.id]);
    });
  }
  async snapshot(model) {
    const result = (await this.store()).snapshot(model);
    const recent = (await this.db.query('SELECT count(*)::int AS requests,coalesce(sum(input_tokens),0)::bigint AS tokens FROM lighau.provider_events WHERE model=$1 AND at>$2', [model, this.now() - 60000])).rows[0];
    return { ...result, persistent: true, minute: { requests: recent.requests, inputTokens: Number(recent.tokens) } };
  }
}

export class PostgresChatLimits extends ChatLimits {
  constructor(database, options) { super(database, options); this.pendingClients = new Set(); }
  async active() {
    await this.db.query('DELETE FROM lighau.leases WHERE expires<=$1', [this.now()]);
    return (await this.db.query('SELECT count(*)::int AS n FROM lighau.leases')).rows[0].n;
  }
  async acquire(client, signal) {
    const key = digest(client);
    // Reserve the process-local queue slot before the first async DB call.
    if (this.pendingClients.has(key)) throw new LimitError('You already have a question waiting.');
    this.pendingClients.add(key);
    const deadline = this.now() + this.waitMs;
    let queued = false;
    try {
      await this.db.transaction(async () => {
        const budget = await this.db.counter(`chat-client:${key}`, this.perClient, 600000, this.now());
        if (!budget.allowed) throw new LimitError('Your question limit was reached. Please wait before trying again.', budget.retryAfter);
      });
      while (true) {
        if (signal?.aborted) throw new LimitError('The request was cancelled.');
        const lease = await this.db.transaction(async () => {
          await this.db.lock('chat-admission');
          const cooldown = (await this.db.query("SELECT resets FROM lighau.counters WHERE key='provider-cooldown' AND resets>$1", [this.now()])).rows[0];
          if (cooldown) throw new LimitError('Gemini usage limits were reached. Please wait before trying again.', Math.ceil((Number(cooldown.resets) - this.now()) / 1000));
          for (const [scope, limit, window] of [['chat-global', this.global, 600000], [`chat-day:${pacificDay(this.now())}`, this.daily, 86400000], ['chat-minute', this.rpm, 60000]]) {
            const result = await this.db.counter(scope, limit, window, this.now(), false);
            if (!result.allowed) throw new LimitError('The assistant usage limit was reached. Please try again later.', result.retryAfter);
          }
          if (await this.active() >= this.concurrency) return null;
          const id = randomUUID();
          await this.db.query('INSERT INTO lighau.leases(id,expires) VALUES ($1,$2)', [id, this.now() + 45000]);
          await this.db.counter('chat-global', this.global, 600000, this.now());
          await this.db.counter(`chat-day:${pacificDay(this.now())}`, this.daily, 86400000, this.now());
          await this.db.counter('chat-minute', this.rpm, 60000, this.now());
          return id;
        });
        if (lease) return lease;
        if (!queued) {
          if (this.waiting.size >= this.queue) throw new LimitError('The assistant queue is full. Please try again shortly.');
          this.waiting.add(key); queued = true;
        }
        if (this.now() >= deadline) throw new LimitError('The assistant is busy. Please try again shortly.');
        await new Promise(resolve => setTimeout(resolve, 50));
      }
    } finally { this.waiting.delete(key); this.pendingClients.delete(key); }
  }
  release(id) { return this.db.query('DELETE FROM lighau.leases WHERE id=$1', [id]); }
  cooldown(seconds = 60) {
    return this.db.transaction(async () => {
      await this.db.lock('chat-admission');
      await this.db.query("INSERT INTO lighau.counters VALUES ('provider-cooldown',1,$1) ON CONFLICT(key) DO UPDATE SET resets=greatest(lighau.counters.resets,excluded.resets)", [this.now() + seconds * 1000]);
    });
  }
  async snapshot() {
    const row = (await this.db.query("SELECT used,resets FROM lighau.counters WHERE key='chat-global' AND resets>$1", [this.now()])).rows[0];
    return { used: row?.used ?? 0, limit: this.global, resetsAt: new Date(Number(row?.resets ?? this.now() + 600000)).toISOString(),
      active: await this.active(), concurrency: this.concurrency, perClient: this.perClient, daily: this.daily, rpm: this.rpm,
      queued: this.waiting.size };
  }
}

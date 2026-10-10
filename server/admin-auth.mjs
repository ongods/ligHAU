import { randomBytes, scrypt, timingSafeEqual, createHash } from 'node:crypto';
import { promisify } from 'node:util';
const derive = promisify(scrypt);
const options = { N: 32768, r: 8, p: 3, maxmem: 64 * 1024 * 1024 };
const digest = (value) => createHash('sha256').update(value).digest('hex');
export { derive, options, digest };
export class AuthError extends Error {
  constructor(status, message, retryAfter) { super(message); this.status = status; this.retryAfter = retryAfter; }
}
export class AdminAuth {
  constructor(database, { now = Date.now, sessionMs = 2 * 60 * 60 * 1000 } = {}) { this.db = database; this.now = now; this.sessionMs = sessionMs; }
  async createAccount(username, password, { reset = false } = {}) {
    username = username.trim().toLowerCase();
    if (!/^[a-z0-9][a-z0-9._@-]{2,99}$/.test(username)) throw new Error('Use a username of 3–100 letters, numbers, dots, underscores, @ or hyphens.');
    if (typeof password !== 'string' || password.length < 15 || password.length > 128) throw new Error('Use a password of 15–128 characters.');
    const salt = randomBytes(16).toString('hex');
    const hash = `${salt}:${(await derive(password, salt, 64, options)).toString('hex')}`;
    this.db.transaction(() => {
      const exists = this.db.sql.prepare('SELECT username FROM accounts WHERE username=?').get(username);
      if (exists && !reset) throw new Error('That admin already exists. Use the reset command to change its password.');
      if (!exists && reset) throw new Error('That admin does not exist.');
      this.db.sql.prepare('INSERT INTO accounts(username,hash,role) VALUES (?,?,?) ON CONFLICT(username) DO UPDATE SET hash=excluded.hash,disabled=0').run(username, hash, 'admin');
      this.db.sql.prepare('DELETE FROM sessions WHERE username=?').run(username);
      this.db.audit('local-admin-tool', reset ? 'admin-password-reset' : 'admin-created', null, { id: username });
    });
  }
  async login(username, password, client) {
    if (typeof username !== 'string' || typeof password !== 'string' || username.length > 100 || password.length > 128) throw new AuthError(401, 'Incorrect admin username or password.');
    username = username.trim().toLowerCase();
    const admission = this.db.transaction(() => {
      for (const [key, limit] of [[`login-ip:${digest(client)}`, 10], [`login-user:${digest(username)}`, 5]]) {
        const result = this.db.counter(key, limit, 900000, this.now(), false);
        if (!result.allowed) return result;
      }
      this.db.counter(`login-ip:${digest(client)}`, 10, 900000, this.now());
      this.db.counter(`login-user:${digest(username)}`, 5, 900000, this.now());
      return { allowed: true };
    });
    if (!admission.allowed) throw new AuthError(429, 'Too many sign-in attempts. Try again later.', admission.retryAfter);
    const account = this.db.sql.prepare('SELECT * FROM accounts WHERE username=?').get(username);
    // Derive even for an unknown account to avoid a fast username-enumeration path.
    const [salt, expected] = (account?.hash ?? `${'0'.repeat(32)}:${'0'.repeat(128)}`).split(':');
    const actual = await derive(password, salt, 64, options);
    if (!account || account.disabled || account.role !== 'admin' || !timingSafeEqual(actual, Buffer.from(expected, 'hex'))) throw new AuthError(401, 'Incorrect admin username or password.');
    const token = randomBytes(32).toString('base64url');
    const expires = this.now() + this.sessionMs;
    this.db.transaction(() => {
      this.db.sql.prepare('DELETE FROM sessions WHERE expires<=?').run(this.now());
      const current = this.db.sql.prepare('SELECT * FROM accounts WHERE username=?').get(username);
      if (!current || current.disabled || current.role !== 'admin' || current.hash !== account.hash) throw new AuthError(401, 'Incorrect admin username or password.');
      this.db.sql.prepare('INSERT INTO sessions VALUES (?,?,?)').run(digest(token), username, expires);
      this.db.sql.prepare('DELETE FROM counters WHERE key=?').run(`login-user:${digest(username)}`);
      this.db.audit(username, 'admin-login', null, null);
    });
    return { token, expiresAt: new Date(expires).toISOString(), username, role: 'admin' };
  }
  require(authorization) {
    const token = /^Bearer ([A-Za-z0-9_-]{43})$/.exec(authorization || '')?.[1];
    if (!token) throw new AuthError(401, 'Sign in as admin.');
    const session = this.db.sql.prepare('SELECT s.username,s.expires,a.role,a.disabled FROM sessions s JOIN accounts a ON a.username=s.username WHERE s.hash=?').get(digest(token));
    if (!session || session.expires <= this.now() || session.disabled || session.role !== 'admin') throw new AuthError(401, 'Your admin session has expired. Sign in again.');
    return session.username;
  }
  logout(authorization) {
    const actor = this.require(authorization);
    this.db.sql.prepare('DELETE FROM sessions WHERE hash=?').run(digest(authorization.slice(7)));
    this.db.audit(actor, 'admin-logout', null, null);
  }
}

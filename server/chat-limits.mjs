import { createHash, randomUUID } from 'node:crypto';
import { pacificDay } from './api-usage.mjs';
export class LimitError extends Error {
  constructor(message, retryAfter = 10) { super(message); this.status = 429; this.retryAfter = retryAfter; }
}
export class ChatLimits {
  constructor(database, { perClient = 5, global = 30, daily = 100, rpm = 5, concurrency = 2, queue = 4, waitMs = 5000, now = Date.now } = {}) {
    this.db = database; this.perClient = perClient; this.global = global; this.daily = daily;
    this.rpm = rpm; this.concurrency = concurrency; this.queue = queue; this.waitMs = waitMs; this.now = now;
    this.waiting = new Set();
  }
  active() { this.db.sql.prepare('DELETE FROM leases WHERE expires<=?').run(this.now()); return this.db.sql.prepare('SELECT count(*) AS n FROM leases').get().n; }
  async acquire(client, signal) {
    const key = createHash('sha256').update(client).digest('hex');
    if (this.waiting.has(key)) throw new LimitError('You already have a question waiting.');
    this.db.transaction(() => {
      const budget = this.db.counter(`chat-client:${key}`, this.perClient, 600000, this.now());
      if (!budget.allowed) throw new LimitError('Your question limit was reached. Please wait before trying again.', budget.retryAfter);
    });
    const deadline = this.now() + this.waitMs;
    let queued = false;
    try {
      while (true) {
        if (signal?.aborted) throw new LimitError('The request was cancelled.');
        const lease = this.db.transaction(() => {
          const cooldown = this.db.sql.prepare("SELECT resets FROM counters WHERE key='provider-cooldown' AND resets>?").get(this.now());
          if (cooldown) throw new LimitError('Gemini usage limits were reached. Please wait before trying again.', Math.ceil((cooldown.resets - this.now()) / 1000));
          for (const [scope, limit, window] of [['chat-global', this.global, 600000], [`chat-day:${pacificDay(this.now())}`, this.daily, 86400000], ['chat-minute', this.rpm, 60000]]) {
            const result = this.db.counter(scope, limit, window, this.now(), false);
            if (!result.allowed) throw new LimitError('The assistant usage limit was reached. Please try again later.', result.retryAfter);
          }
          if (this.active() >= this.concurrency) return null;
          const id = randomUUID();
          this.db.sql.prepare('INSERT INTO leases VALUES (?,?)').run(id, this.now() + 45000);
          this.db.counter('chat-global', this.global, 600000, this.now());
          this.db.counter(`chat-day:${pacificDay(this.now())}`, this.daily, 86400000, this.now());
          this.db.counter('chat-minute', this.rpm, 60000, this.now());
          return id;
        });
        if (lease) return lease;
        if (!queued) {
          if (this.waiting.size >= this.queue) throw new LimitError('The assistant queue is full. Please try again shortly.');
          this.waiting.add(key); queued = true;
        }
        if (this.now() >= deadline) throw new LimitError('The assistant is busy. Please try again shortly.');
        await new Promise((resolve) => setTimeout(resolve, 50));
      }
    } finally { if (queued) this.waiting.delete(key); }
  }
  release(id) { this.db.sql.prepare('DELETE FROM leases WHERE id=?').run(id); }
  cooldown(seconds = 60) {
    this.db.sql.prepare("INSERT INTO counters VALUES ('provider-cooldown',1,?) ON CONFLICT(key) DO UPDATE SET resets=max(resets,excluded.resets)").run(this.now() + seconds * 1000);
  }
  snapshot() {
    const row = this.db.sql.prepare("SELECT used,resets FROM counters WHERE key='chat-global' AND resets>?").get(this.now());
    return { used: row?.used ?? 0, limit: this.global, resetsAt: new Date(row?.resets ?? this.now() + 600000).toISOString(), active: this.active(), concurrency: this.concurrency,
      perClient: this.perClient, daily: this.daily, rpm: this.rpm, queued: this.waiting.size, queue: this.queue };
  }
}

import { UsageStore } from './api-usage.mjs';
export class SqliteUsageStore extends UsageStore {
  constructor(database, legacyFile) {
    super({ file: database.get('usage') ? undefined : legacyFile });
    if (this.storageError) throw new Error('Existing API usage data is invalid; migration stopped.');
    this.db = database;
    this.file = undefined;
    database.transaction(() => {
      if (!database.get('usage')) database.set('usage', this.state);
    });
  }
  save() { this.db.set('usage', this.state); }
  start(model) {
    return this.db.transaction(() => {
      this.state = this.db.get('usage');
      const event = super.start(model);
      event.id = Number(this.db.sql.prepare('INSERT INTO provider_events(model,at) VALUES (?,?)').run(model, event.at).lastInsertRowid);
      this.db.sql.prepare('DELETE FROM provider_events WHERE at<?').run(event.at - 86400000);
      return event;
    });
  }
  finish(event, result) {
    this.db.transaction(() => {
      this.state = this.db.get('usage');
      super.finish(event, result);
      this.db.sql.prepare('UPDATE provider_events SET input_tokens=? WHERE id=?').run(event.inputTokens, event.id);
    });
  }
  snapshot(model) {
    this.state = this.db.get('usage');
    const result = super.snapshot(model);
    const recent = this.db.sql.prepare('SELECT count(*) AS requests,coalesce(sum(input_tokens),0) AS tokens FROM provider_events WHERE model=? AND at>?').get(model, Date.now() - 60000);
    return { ...result, persistent: this.db.file !== ':memory:', minute: { requests: recent.requests, inputTokens: recent.tokens } };
  }
}

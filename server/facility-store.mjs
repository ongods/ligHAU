import { createHash, randomUUID } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, renameSync, writeFileSync } from 'node:fs';
import { dirname } from 'node:path';

export class CatalogError extends Error {
  constructor(status, message) { super(message); this.status = status; }
}

function validate(value) {
  const result = {};
  for (const [key, max] of Object.entries({ name: 200, category: 100, location: 500, description: 6000, hours: 200 })) {
    if (typeof value?.[key] !== 'string' || !value[key].trim() || value[key].length > max) throw new CatalogError(400, `Invalid ${key}.`);
    result[key] = value[key].trim();
  }
  if (!Array.isArray(value.facilities) || value.facilities.length > 100 || value.facilities.some((item) => typeof item !== 'string' || item.length > 300)) throw new CatalogError(400, 'Invalid facilities.');
  result.facilities = [...new Set(value.facilities.map((item) => item.trim()).filter(Boolean))];
  if (value.floors !== null && (!Number.isInteger(value.floors) || value.floors < 1 || value.floors > 200)) throw new CatalogError(400, 'Invalid floor count.');
  result.floors = value.floors;
  const latitude = value.latitude ?? null;
  const longitude = value.longitude ?? null;
  if ((latitude === null) !== (longitude === null) ||
      (latitude !== null && (typeof latitude !== 'number' || !Number.isFinite(latitude) || latitude < -90 || latitude > 90 ||
        typeof longitude !== 'number' || !Number.isFinite(longitude) || longitude < -180 || longitude > 180))) {
    throw new CatalogError(400, 'Provide valid latitude and longitude together.');
  }
  result.latitude = latitude;
  result.longitude = longitude;
  return result;
}

export class FacilityStore {
  constructor({ catalog, file, database } = {}) {
    this.database = database;
    this.file = file;
    this.records = database?.get('catalog') ?? (file && existsSync(file) ? JSON.parse(readFileSync(file, 'utf8')) : catalog.map((item) => ({
      ...item, id: createHash('sha256').update(item.name).digest('hex').slice(0, 24), sourceName: item.name,
      hasOriginalMapLocation: Boolean(item.hasMapLocation),
    })));
    if (!Array.isArray(this.records) || this.records.some((item) => !item.id || !item.name)) throw new Error('Saved campus catalog is invalid.');
    this.records = this.records.map((item) => ({ ...item,
      version: item.version ?? 1,
      hasOriginalMapLocation: item.hasOriginalMapLocation ?? Boolean(item.sourceName && item.hasMapLocation),
    }));
    if (database) database.transaction(() => {
      if (!database.get('catalog')) database.set('catalog', this.records);
    });
  }
  all() { return this.database ? this.database.get('catalog') : structuredClone(this.records); }
  save(next, audit) {
    if (this.database) {
      this.database.set('catalog', next);
      if (audit) this.database.audit(audit.actor, audit.operation, audit.before, audit.after);
    }
    if (this.file && !this.database) {
      try {
        mkdirSync(dirname(this.file), { recursive: true });
        writeFileSync(`${this.file}.tmp`, JSON.stringify(next), { mode: 0o600 });
        renameSync(`${this.file}.tmp`, this.file);
      } catch { throw new CatalogError(500, 'Could not save the campus catalog.'); }
    }
    this.records = next;
    return this.all();
  }
  upsert(id, value, actor = 'local') {
    const operation = () => this._upsert(id, value, actor);
    return this.database ? this.database.transaction(operation) : operation();
  }
  _upsert(id, value, actor) {
    this.records = this.all();
    const index = id ? this.records.findIndex((item) => item.id === id) : -1;
    if (id && index < 0) throw new CatalogError(404, 'This place no longer exists.');
    const fields = validate(value);
    if (this.records.some((item) => item.id !== id && item.name.toLowerCase() === fields.name.toLowerCase())) throw new CatalogError(409, 'A place with this name already exists.');
    const existing = this.records[index];
    if (id && this.database) this.checkVersion(existing, value.version);
    const record = { ...fields, id: existing?.id ?? randomUUID(), sourceName: existing?.sourceName ?? null,
      version: (existing?.version ?? 0) + 1,
      hasOriginalMapLocation: existing?.hasOriginalMapLocation ?? false,
      hasMapLocation: fields.latitude !== null || (existing?.hasOriginalMapLocation ?? false), hoursVerified: false };
    const next = this.all();
    if (index < 0) next.push(record); else next[index] = record;
    return this.save(next, { actor, operation: id ? 'facility-updated' : 'facility-created', before: existing, after: record });
  }
  checkVersion(existing, version) {
    if (!Number.isInteger(version)) throw new CatalogError(428, 'Reload this place before saving changes.');
    if (version !== existing.version) throw new CatalogError(412, 'Someone else changed this place. Reload it and review your changes.');
  }
  remove(id, { version, actor = 'local' } = {}) {
    const operation = () => {
      this.records = this.all();
      const existing = this.records.find((item) => item.id === id);
      if (!existing) throw new CatalogError(404, 'This place no longer exists.');
      if (this.database) this.checkVersion(existing, version);
      return this.save(this.records.filter((item) => item.id !== id), { actor, operation: 'facility-deleted', before: existing });
    };
    return this.database ? this.database.transaction(operation) : operation();
  }
}

import { fileURLToPath } from 'node:url';
import { AppDatabase, defaultDatabaseFile } from './database.mjs';
import { FacilityStore } from './facility-store.mjs';
import { AdminAuth } from './admin-auth.mjs';
import { ChatLimits } from './chat-limits.mjs';
import { SqliteUsageStore } from './sqlite-usage.mjs';
import { loadCampusData } from './campus-data.mjs';

export async function openBackendStorage({ env = process.env, limits, initialize = true } = {}) {
  const driver = env.DATABASE_DRIVER || 'sqlite';
  if (!['sqlite', 'postgres'].includes(driver)) throw new Error('DATABASE_DRIVER must be sqlite or postgres.');
  if (driver === 'postgres') {
    const { PostgresDatabase } = await import('./postgres-database.mjs');
    const { PostgresFacilityStore, PostgresAdminAuth, PostgresChatLimits, PostgresUsageStore } = await import('./postgres-services.mjs');
    const database = await PostgresDatabase.connect({ env });
    try {
      const facilityStore = new PostgresFacilityStore(database);
      if (initialize) await facilityStore.initialize(loadCampusData());
      return { database, facilityStore, auth: new PostgresAdminAuth(database), limiter: new PostgresChatLimits(database, limits), usage: new PostgresUsageStore(database) };
    } catch (error) { await database.close(); throw error; }
  }
  if (env.NODE_ENV === 'production' && !env.CAMPUS_DB_PATH) throw new Error('Production SQLite requires CAMPUS_DB_PATH on a persistent volume.');
  const database = new AppDatabase(env.CAMPUS_DB_PATH || defaultDatabaseFile());
  try {
    return { database, auth: new AdminAuth(database), limiter: new ChatLimits(database, limits),
      usage: new SqliteUsageStore(database, fileURLToPath(new URL('./.local/api-usage.json', import.meta.url))),
      facilityStore: new FacilityStore({ database, catalog: loadCampusData(), file: fileURLToPath(new URL('./.local/facilities.json', import.meta.url)) }) };
  } catch (error) { database.close(); throw error; }
}

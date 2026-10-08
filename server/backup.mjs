import { existsSync, mkdirSync, copyFileSync, constants, chmodSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import { AppDatabase, defaultDatabaseFile } from './database.mjs';

const [command, source, destination] = process.argv.slice(2);
let database;
try {
  if (command === 'backup' && source && !destination) {
    const target = resolve(source);
    if (existsSync(target)) throw new Error('Backup destination already exists. Choose a new file.');
    if (!existsSync(defaultDatabaseFile())) throw new Error('No campus database exists yet.');
    mkdirSync(dirname(target), { recursive: true });
    database = new AppDatabase(defaultDatabaseFile());
    if (!database.integrity()) throw new Error('Database integrity check failed.');
    database.backup(target);
    chmodSync(target, 0o600);
    console.log('Consistent database backup created. Protect it like the live database.');
  } else if (command === 'restore' && source && destination) {
    const target = resolve(destination);
    if (existsSync(target)) throw new Error('Restore target already exists. Restore to a new database file.');
    const check = new DatabaseSync(resolve(source), { readOnly: true });
    try {
      if (check.prepare('PRAGMA integrity_check').get().integrity_check !== 'ok' || !check.prepare("SELECT name FROM sqlite_master WHERE name='settings'").get()) throw new Error('Backup is not a valid campus database.');
    } finally { check.close(); }
    mkdirSync(dirname(target), { recursive: true });
    copyFileSync(resolve(source), target, constants.COPYFILE_EXCL);
    chmodSync(target, 0o600);
    database = new AppDatabase(target);
    database.transaction(() => {
      database.sql.exec('DELETE FROM sessions; DELETE FROM leases;');
      database.audit('local-backup-tool', 'database-restored', null, null);
    });
    console.log('Backup restored to a new file; sessions revoked. Stop the backend, set CAMPUS_DB_PATH to that file, then restart.');
  } else throw new Error('Usage: node --env-file=.env server/backup.mjs backup FILE, or restore BACKUP NEW_DATABASE');
} catch (error) { console.error(error.message); process.exitCode = 1; }
finally { database?.close(); }

import { openBackendStorage } from './backend-storage.mjs';
import { hiddenPassword } from './terminal-password.mjs';

const [command, username] = process.argv.slice(2);
let database;
try {
  if (!['create', 'reset', 'disable', 'list'].includes(command) || (command !== 'list' && !username)) throw new Error('Usage: node --env-file=.env server/manage-admin.mjs create|reset|disable USERNAME, or list');
  const storage = await openBackendStorage({ initialize: false });
  database = storage.database;
  const auth = storage.auth;
  if (command === 'list') {
    const accounts = database.driver === 'postgres' ? await auth.list() : database.sql.prepare('SELECT username,role,disabled FROM accounts').all();
    for (const account of accounts) console.log(`${account.username}: ${account.role}${account.disabled ? ' (disabled)' : ''}`);
  } else if (command === 'disable') {
    if (database.driver === 'postgres') await auth.disable(username);
    else database.transaction(() => {
      const result = database.sql.prepare('UPDATE accounts SET disabled=1 WHERE username=?').run(username.toLowerCase());
      if (!result.changes) throw new Error('That admin does not exist.');
      database.sql.prepare('DELETE FROM sessions WHERE username=?').run(username.toLowerCase());
      database.audit('local-admin-tool', 'admin-disabled', null, { id: username.toLowerCase() });
    });
    console.log('Account disabled and sessions revoked.');
  } else {
    const password = await hiddenPassword('Password (15–128 characters, hidden): ');
    const confirm = await hiddenPassword('Confirm password (hidden): ');
    if (password !== confirm) throw new Error('Passwords do not match.');
    await auth.createAccount(username, password, { reset: command === 'reset' });
    console.log(`Admin ${command === 'reset' ? 'password reset' : 'created'}. Sign in through the app.`);
  }
} catch (error) { console.error(database ? error.message : 'Cannot open the database. Check settings, runtime role and migration.'); process.exitCode = 1; }
finally { await database?.close(); }

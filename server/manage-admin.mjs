import { stdin, stdout } from 'node:process';
import { AppDatabase, defaultDatabaseFile } from './database.mjs';
import { AdminAuth } from './admin-auth.mjs';

async function hiddenPassword(prompt) {
  if (!stdin.isTTY) throw new Error('Run this command in an interactive terminal; passwords are not accepted as command-line arguments.');
  stdout.write(prompt);
  stdin.setRawMode(true); stdin.resume(); stdin.setEncoding('utf8');
  return new Promise((resolve, reject) => {
    let value = '';
    const cleanup = () => { stdin.off('data', receive); stdin.setRawMode(false); stdin.pause(); stdout.write('\n'); };
    const receive = (chunk) => {
      for (const char of chunk) {
        if (char === '\u0003') { cleanup(); reject(new Error('Cancelled.')); return; }
        if (char === '\r' || char === '\n') { cleanup(); resolve(value); return; }
        if (char === '\u007f' || char === '\b') value = [...value].slice(0, -1).join('');
        else if (char >= ' ') value += char;
      }
    };
    stdin.on('data', receive);
  });
}

const [command, username] = process.argv.slice(2);
let database;
try {
  if (!['create', 'reset', 'disable', 'list'].includes(command) || (command !== 'list' && !username)) throw new Error('Usage: node --env-file=.env server/manage-admin.mjs create|reset|disable USERNAME, or list');
  database = new AppDatabase(defaultDatabaseFile());
  const auth = new AdminAuth(database);
  if (command === 'list') {
    for (const account of database.sql.prepare('SELECT username,role,disabled FROM accounts').all()) console.log(`${account.username}: ${account.role}${account.disabled ? ' (disabled)' : ''}`);
  } else if (command === 'disable') {
    database.transaction(() => {
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
} catch (error) { console.error(error.message); process.exitCode = 1; }
finally { database?.close(); }

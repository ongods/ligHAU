import { PostgresDatabase } from './postgres-database.mjs';
import { hiddenPassword } from './terminal-password.mjs';

let database;
let stage = 'command options';
class SetupError extends Error {}
try {
  if (!process.argv.includes('--apply')) throw new SetupError('Run with --apply to set the restricted database role password.');
  if (!process.env.DATABASE_MIGRATION_URL) throw new SetupError('Set DATABASE_MIGRATION_URL privately to the schema-owner connection string.');
  stage = 'password entry';
  const password = await hiddenPassword('Database password for lighau_backend (15–128 characters, hidden): ');
  const confirm = await hiddenPassword('Confirm database password (hidden): ');
  if (password !== confirm) throw new SetupError('The two passwords did not match. Run the command again and enter the same new password twice.');
  if (password.length < 15 || password.length > 128) throw new SetupError('The new database password must contain 15–128 characters. Run the command again with a password of that length.');
  stage = 'owner connection';
  database = await PostgresDatabase.connect({ connectionString: process.env.DATABASE_MIGRATION_URL, maintenance: true });
  // PostgreSQL ALTER ROLE does not accept bound password parameters. Use the
  // server's quote_literal and SCRAM encryption; never print or persist this SQL.
  stage = 'database role password update';
  await database.transaction(async () => {
    await database.query("SET LOCAL password_encryption = 'scram-sha-256'");
    const literal = (await database.query('SELECT quote_literal($1) AS value', [password])).rows[0].value;
    await database.query(`ALTER ROLE lighau_backend PASSWORD ${literal}`);
  });
  console.log('Restricted database password set. Update DATABASE_URL privately to use lighau_backend and this password.');
} catch (error) {
  const reasons = {
    '28P01': 'The owner database password was rejected. Check DATABASE_MIGRATION_URL privately.',
    '42501': 'The connected owner does not have permission to update lighau_backend. Check the role grants before retrying.',
    '42704': 'The lighau_backend role is missing. Apply the prepared migration first.',
    SELF_SIGNED_CERT_IN_CHAIN: 'The database certificate could not be verified. Check DATABASE_CA_FILE.',
    ENOENT: 'The certificate file could not be found. Check DATABASE_CA_FILE.',
    ENOTFOUND: 'The database host could not be found. Check the owner connection address.',
  };
  const code = typeof error.code === 'string' && /^[A-Z0-9_]+$/.test(error.code) ? error.code : undefined;
  console.error(`Database-role setup stopped: ${error instanceof SetupError ? error.message : reasons[code] ?? `Failed during ${stage}${code ? ` (${code})` : ''}. Check the private settings; no credentials are printed.`}`);
  process.exitCode = 1;
}
finally { await database?.close(); }

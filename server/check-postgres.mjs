import { PostgresDatabase } from './postgres-database.mjs';

let database;
try {
  const owner = process.argv.includes('--owner');
  if (owner && !process.env.DATABASE_MIGRATION_URL) throw new Error('Missing owner connection setting.');
  database = await PostgresDatabase.connect({ maintenance: true,
    ...(owner ? { connectionString: process.env.DATABASE_MIGRATION_URL } : {}) });
  const { rows: [role] } = await database.query('SELECT rolsuper,rolbypassrls FROM pg_roles WHERE rolname=current_user');
  // A pooler terminates client TLS, so pg_stat_ssl describes a different hop.
  const client = await database.pool.connect();
  let ssl;
  try { ssl = client.connection.stream.encrypted === true && client.connection.stream.authorized === true; }
  finally { client.release(); }
  const schema = Boolean((await database.query("SELECT 1 FROM information_schema.schemata WHERE schema_name='lighau'")).rowCount);
  const result = { connected: true, tls: ssl, restrictedRole: !role.rolsuper && !role.rolbypassrls, schemaPresent: schema };
  result.backendRolePresent = Boolean((await database.query("SELECT 1 FROM pg_roles WHERE rolname='lighau_backend'")).rowCount);
  if (schema) {
    result.schemaVersion = await database.get('schema_version');
    result.catalogInitialized = Boolean(await database.get('catalog_initialized'));
    result.catalogCount = (await database.query('SELECT count(*)::int AS n FROM lighau.facilities')).rows[0].n;
  }
  console.log(JSON.stringify(result));
} catch (error) {
  // Driver errors can contain connection details: never print the raw error.
  console.error(`Database check failed${typeof error.code === 'string' && /^[A-Z0-9_]+$/.test(error.code) ? ` (${error.code})` : ''}. Check the URL, password, TLS certificate and permissions privately.`);
  process.exitCode = 1;
} finally { await database?.close(); }

import { AppDatabase } from './database.mjs';
import { AdminAuth } from './admin-auth.mjs';
export async function testAdmin() {
  const database = new AppDatabase();
  const auth = new AdminAuth(database);
  await auth.createAccount('test-admin', 'test-admin-password');
  const session = await auth.login('test-admin', 'test-admin-password', 'test-client');
  return { database, auth, headers: { Authorization: `Bearer ${session.token}`, 'Content-Type': 'application/json' } };
}

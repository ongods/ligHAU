// Explicit staging verification only. Creates/deletes one uniquely named test place.
// No hosting, deployment, or remote restart is performed by this script.
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
const app = process.env.SMOKE_APP_URL;
const api = process.env.SMOKE_API_URL || app;
if (!app || !api || !process.argv.includes('--allow-staging-writes')) {
  throw new Error('Set SMOKE_APP_URL, SMOKE_API_URL, SMOKE_ADMIN_USERNAME and SMOKE_ADMIN_PASSWORD, then run with --allow-staging-writes. Use a dedicated staging environment.');
}
for (const value of [app, api]) if (new URL(value).protocol !== 'https:') throw new Error('Staging checks require HTTPS.');
let headers;
let created;
const call = async (path, options = {}) => {
  const response = await fetch(new URL(path, api), { ...options, signal: AbortSignal.timeout(45000) });
  assert.equal(response.status, 200, `Staging ${path} returned HTTP ${response.status}`);
  return response.json();
};
try {
  assert.equal((await fetch(app)).status, 200);
  assert.equal((await call('/health')).service, 'ligHAU-chat');
  const login = await call('/api/admin/login', { method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username: process.env.SMOKE_ADMIN_USERNAME, password: process.env.SMOKE_ADMIN_PASSWORD }) });
  headers = { Authorization: `Bearer ${login.token}`, 'Content-Type': 'application/json' };
  const name = `Staging probe ${randomUUID()}`;
  const values = { name, category: 'Buildings', location: 'Staging test record', description: 'Temporary deployment verification record', hours: '8:00 AM – 5:00 PM', floors: null,
    facilities: [], latitude: 15.1325, longitude: 120.5901 };
  created = (await call('/api/admin/facilities', { method: 'POST', headers, body: JSON.stringify(values) })).facilities.find((f) => f.name === name);
  assert.ok(created?.hasMapLocation);
  const changed = await call(`/api/admin/facilities/${created.id}`, { method: 'PUT', headers,
    body: JSON.stringify({ ...created, description: 'Updated staging probe' }) });
  created = changed.facilities.find((f) => f.id === created.id);
  assert.equal((await call('/api/facilities')).facilities.find((f) => f.id === created.id).description, 'Updated staging probe');
  await call('/api/admin/usage', { headers });
  if (process.argv.includes('--one-chat')) {
    const reply = await call('/api/chat', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ messages: [{ role: 'user', text: 'Where is the campus library?' }] }) });
    assert.ok(reply.answer && Array.isArray(reply.facilityNames));
  }
  if (process.argv.includes('--browser')) {
    // Optional prerequisite: install Playwright and Chrome on the staging test runner.
    const { chromium } = await import('playwright');
    const browser = await chromium.launch({ channel: 'chrome', headless: true });
    try {
      const page = await browser.newPage();
      await page.goto(app);
      await page.locator('flt-semantics-placeholder').click({ force: true });
      const tile = page.waitForResponse((r) => r.url().includes('api.maptiler.com') && /\.(pbf|png|jpg)(\?|$)/.test(r.url()) && r.status() === 200, { timeout: 45000 });
      await page.getByRole('button', { name: /Continue as Guest/ }).click();
      await tile;
      await page.waitForFunction(() => !!document.querySelector('.maplibregl-map canvas'), null, { timeout: 45000 });
      assert.equal(await page.getByText(/The map couldn.t load/).count(), 0);
    } finally { await browser.close(); }
  }
  console.log('Staging smoke checks passed. Persistence after a real hosted restart and staging soak remain separate checks.');
} finally {
  if (headers && created) await call(`/api/admin/facilities/${created.id}`, { method: 'DELETE', headers: { ...headers, 'If-Match': `"${created.version}"` } });
  if (headers) await call('/api/admin/logout', { method: 'POST', headers });
}

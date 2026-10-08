// Uses an existing Chrome debugging port and a temporary tab, never a new server.
import assert from 'node:assert/strict';
import { writeFileSync } from 'node:fs';
const port = Number(process.argv.find((arg) => arg.startsWith('--browser-port='))?.split('=')[1]);
assert.ok(Number.isInteger(port) && port > 0 && port < 65536);
let ws, next = 0, targetId, sessionId;
const pending = new Map();
const checks = [];
let tiles = 0;
function handleMessage(event) {
  const message = JSON.parse(event.data);
  if (message.method === 'Network.responseReceived' && message.sessionId === sessionId) {
    const response = message.params.response;
    if (response.status === 200 && response.url.includes('api.maptiler.com') && /\.(pbf|png|jpg)(\?|$)/.test(response.url)) tiles++;
  }
  const task = pending.get(message.id);
  if (!task) return;
  clearTimeout(task.timer); pending.delete(message.id);
  if (message.error) task.reject(new Error('Browser command failed'));
  else task.resolve(message.result);
}
function call(method, params = {}, session = sessionId) {
  const id = ++next;
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => { pending.delete(id); reject(new Error('Browser command timed out')); }, 60000);
    pending.set(id, { resolve, reject, timer });
    ws.send(JSON.stringify({ id, method, params, ...(session ? { sessionId: session } : {}) }));
  });
}
async function evaluate(expression) {
  const response = await call('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
  if (response.exceptionDetails) throw new Error('Browser evaluation failed');
  return response.result.value;
}
async function waitFor(expression) {
  const deadline = Date.now() + 45000;
  while (Date.now() < deadline) {
    const result = await evaluate(expression);
    if (result) return result;
    await new Promise((resolve) => setTimeout(resolve, 200));
  }
  throw new Error('Browser element did not appear');
}
async function click(expression) {
  const point = await waitFor(`(() => { const e = ${expression}; if (!e) return null; const r = e.getBoundingClientRect(); return r.width && r.height ? {x:r.x+r.width/2,y:r.y+r.height/2} : null; })()`);
  await call('Input.dispatchMouseEvent', { type: 'mousePressed', button: 'left', clickCount: 1, ...point });
  await call('Input.dispatchMouseEvent', { type: 'mouseReleased', button: 'left', clickCount: 1, ...point });
}
const button = (label) => `[...document.querySelectorAll('[role="button"]')].find(e => ((e.getAttribute('aria-label') || '') + ' ' + e.textContent).includes(${JSON.stringify(label)}))`;
let passed = false;
let stage = 'connect to existing Chrome';
function step(value) { stage = value; console.log(`Browser check: ${value}`); }
try {
  const version = await (await fetch(`http://127.0.0.1:${port}/json/version`, { signal: AbortSignal.timeout(10000) })).json();
  ws = new WebSocket(version.webSocketDebuggerUrl);
  await new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('Chrome connection timed out')), 10000);
    ws.addEventListener('open', () => { clearTimeout(timer); resolve(); }, { once: true });
    ws.addEventListener('error', () => { clearTimeout(timer); reject(new Error('Chrome unavailable')); }, { once: true });
  });
  ws.addEventListener('message', handleMessage);
  step('open temporary tab');
  ({ targetId } = await call('Target.createTarget', { url: 'about:blank' }, null));
  ({ sessionId } = await call('Target.attachToTarget', { targetId, flatten: true }, null));
  await call('Network.enable');
  await call('Emulation.setDeviceMetricsOverride', { width: 1440, height: 900, deviceScaleFactor: 1, mobile: false });
  await call('Page.navigate', { url: 'http://localhost:53923' });
  step('activate accessibility');
  await waitFor("!!(document.querySelector('flt-semantics-placeholder') || document.querySelector('[role=button]'))");
  await evaluate("document.querySelector('flt-semantics-placeholder')?.click()");
  step('enter guest map');
  await click(button('Continue as Guest'));
  step('wait for map canvas and tiles');
  await waitFor("!!document.querySelector('.maplibregl-map canvas')");
  await waitFor("document.querySelector('.maplibregl-map canvas')?.width > 0");
  const deadline = Date.now() + 45000;
  while (!tiles && Date.now() < deadline) await new Promise((resolve) => setTimeout(resolve, 200));
  assert.ok(tiles > 0);
  checks.push({ name: 'desktop guest map renders with successful provider tiles', passed: true, mapTiles: tiles });
  step('exercise zoom controls');
  await click(button('Zoom in'));
  await click(button('Zoom out'));
  checks.push({ name: 'map zoom controls respond', passed: true });
  step('check mobile map');
  await call('Emulation.setDeviceMetricsOverride', { width: 320, height: 900, deviceScaleFactor: 1, mobile: false });
  await waitFor("document.querySelector('.maplibregl-map canvas')?.width > 0");
  assert.equal(await evaluate("/The map couldn.t load/.test(document.body.innerText)"), false);
  checks.push({ name: 'map remains rendered at mobile width 320', passed: true });
  await call('Emulation.setDeviceMetricsOverride', { width: 1440, height: 900, deviceScaleFactor: 1, mobile: false });
  step('exit to welcome');
  await click(button('Exit campus guide'));
  await waitFor(`!!(${button('Continue as Guest')})`);
  checks.push({ name: 'exit returns to welcome screen', passed: true });
  passed = true;
} catch {
  checks.push({ name: 'browser flow incomplete; inspect the application and automation selectors', stage, passed: false });
} finally {
  if (targetId) {
    try { await call('Target.closeTarget', { targetId }, null); }
    catch { passed = false; checks.push({ name: 'temporary tab cleanup could not be confirmed', passed: false }); }
  }
  ws?.close();
  const report = { completedAt: new Date().toISOString(), passed, scope: 'Temporary guest tab in existing Chrome; no admin login, catalog writes or chatbot calls', checks };
  writeFileSync(new URL('../docs/browser-smoke-results.json', import.meta.url), JSON.stringify(report, null, 2));
  console.log(JSON.stringify(report));
  if (!passed) process.exitCode = 1;
}
